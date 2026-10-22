#!/usr/bin/env python3
"""HomeLab07 medical exam synchronization for Paperless-ngx (Sprint 015).

Commands:
  sync                 upload new exams from the read-only source folder
  preview              print the date, category and title of every source file;
                       no Paperless access, nothing uploaded
  model-init           create the Paperless data model (requires an administrator token)
  next-delay           print seconds until the next scheduled run
  wait-ready           wait until Paperless answers HTTP (used once at start-up)
  wait-change SECONDS  wait up to SECONDS for a stable change in the source folder

Only the Python standard library is used.
"""

import datetime as dt
import fcntl
import getpass
import hashlib
import http.client
import json
import os
import re
import secrets
import subprocess
import sys
import tempfile
import time
import unicodedata
import urllib.parse
import uuid

# -----------------------------------------------------------------------------
# Contract constants (Sprint 015)
# -----------------------------------------------------------------------------

API_VERSION = 10
DOCUMENT_TYPE = "Examen médico"
TAG_MEDICAL = "medico"
TAG_REVIEW_DATE = "revisar-fecha"
TAG_REVIEW_TITLE = "revisar-titulo"
FIELD_PATH = "Ruta origen"
FIELD_HASH = "Hash origen"
SYNC_USERNAME = "sync-medico"
WORKFLOW_NAME = "Exámenes médicos"
SYNC_PERMISSIONS = [
    "view_document",
    "add_document",
    "view_tag",
    "view_documenttype",
    "view_customfield",
    "view_paperlesstask",
]

# Read-only users (SYNC_READER_USERNAMES) can view exams and their metadata
# but never add, change or delete anything.
READER_PERMISSIONS = [
    "view_document",
    "view_tag",
    "view_correspondent",
    "view_documenttype",
    "view_customfield",
]

# Paperless enums used by the workflow definition.
MATCH_NONE = 0
TRIGGER_DOCUMENT_ADDED = 2
SOURCE_API_UPLOAD = 2
ACTION_ASSIGNMENT = 1

SOURCE_DIR = "/source"
METRICS_DIR = "/metrics"
WORK_DIR = "/run/sync"
LOCK_FILE = os.path.join(WORK_DIR, "sync.lock")
SNAPSHOT_FILE = os.path.join(WORK_DIR, "snapshot")
METRICS_FILE = "paperless-medical-sync.prom"
METRICS_PREFIX = "homelab07_paperless_medical_sync"

SUPPORTED_EXTENSIONS = {".pdf", ".png", ".jpg", ".jpeg"}
CHUNK_SIZE = 1024 * 1024

EXIT_OK = 0
EXIT_FAILED = 1
EXIT_LOCKED = 3
EXIT_UNREACHABLE = 75

MONTHS = {
    "enero": 1, "febrero": 2, "marzo": 3, "abril": 4, "mayo": 5, "junio": 6,
    "julio": 7, "agosto": 8, "septiembre": 9, "setiembre": 9, "octubre": 10,
    "noviembre": 11, "diciembre": 12,
}

RESULTS = (
    "uploaded", "skipped", "modified", "duplicate",
    "encrypted_no_password", "unsupported", "failed", "deferred",
)


class Unreachable(Exception):
    """Paperless could not be reached; the run should be retried soon."""


class ApiError(Exception):
    def __init__(self, message, status=None):
        super().__init__(message)
        self.status = status


def log(message):
    print(f"{dt.datetime.now().isoformat(timespec='seconds')} {message}", flush=True)


# -----------------------------------------------------------------------------
# Text helpers
# -----------------------------------------------------------------------------

def nfc(value):
    return unicodedata.normalize("NFC", value)


def fold(value):
    """Case- and accent-insensitive form used for folder matching."""
    decomposed = unicodedata.normalize("NFD", value.casefold())
    return "".join(c for c in decomposed if unicodedata.category(c) != "Mn").strip()


def int_env(name, default):
    try:
        return int(os.environ.get(name, "").strip() or default)
    except ValueError:
        raise SystemExit(f"{name} must be an integer") from None


def json_env(name, default):
    raw = os.environ.get(name, "").strip()
    if not raw:
        return default
    try:
        return json.loads(raw)
    except json.JSONDecodeError as error:
        raise SystemExit(f"{name} is not valid JSON: {error.msg}") from None


# -----------------------------------------------------------------------------
# Paperless API client
# -----------------------------------------------------------------------------

class Paperless:
    def __init__(self, base_url, token):
        parsed = urllib.parse.urlsplit(base_url)
        if parsed.scheme not in ("http", "https") or not parsed.hostname:
            raise SystemExit("PAPERLESS_INTERNAL_URL must be an http(s) URL")
        self.scheme = parsed.scheme
        self.host = parsed.hostname
        self.port = parsed.port
        self.base_path = parsed.path.rstrip("/")
        self.headers = {"Accept": f"application/json; version={API_VERSION}"}
        if token:
            self.headers["Authorization"] = f"Token {token}"
        # Replaced by Namer.mask so error excerpts never expose personal data.
        self.redact = lambda text: text

    def _connection(self, timeout=60):
        cls = http.client.HTTPSConnection if self.scheme == "https" else http.client.HTTPConnection
        return cls(self.host, self.port, timeout=timeout)

    def request(self, method, path, query=None, body=None, headers=None, timeout=60):
        url = self.base_path + path
        if query:
            url += "?" + urllib.parse.urlencode(query)
        all_headers = dict(self.headers)
        all_headers.update(headers or {})
        if isinstance(body, (dict, list)):
            body = json.dumps(body).encode()
            all_headers["Content-Type"] = "application/json"
        connection = self._connection(timeout)
        try:
            connection.request(method, url, body=body, headers=all_headers)
            response = connection.getresponse()
            payload = response.read()
        except (OSError, http.client.HTTPException) as error:
            # Only connection-level errors abort the run and trigger the retry.
            raise Unreachable(f"{method} {path}: {error.__class__.__name__}") from None
        finally:
            connection.close()
        if response.status >= 400:
            excerpt = self.redact(payload[:300].decode("utf-8", "replace"))
            raise ApiError(f"{method} {path}: HTTP {response.status}: {excerpt}", response.status)
        self.last_api_version = response.getheader("X-Api-Version")
        if not payload:
            return None
        return json.loads(payload)

    def get(self, path, **query):
        return self.request("GET", path, query=query or None)

    def post(self, path, body):
        return self.request("POST", path, body=body)

    def results(self, path, **query):
        query.setdefault("page_size", 100)
        data = self.get(path, **query)
        items = data.get("results", []) if isinstance(data, dict) else (data or [])
        return items

    def all_results(self, path, **query):
        """Yield every item of a paginated list endpoint."""
        page = 1
        while True:
            data = self.get(path, page=page, page_size=100, **query)
            if not isinstance(data, dict):
                yield from data or []
                return
            yield from data.get("results", [])
            if not data.get("next"):
                return
            page += 1

    def find_by_name(self, path, name, field="name"):
        wanted = nfc(name).casefold()

        def match(items):
            for item in items:
                if nfc(str(item.get(field, ""))).casefold() == wanted:
                    return item
            return None

        if item := match(self.results(path, **{f"{field}__iexact": name})):
            return item
        # The server compares raw strings, so a name stored in another Unicode
        # form (for example NFD from a macOS client) is only found locally.
        return match(self.all_results(path))

    def check_version(self):
        try:
            self.get("/api/document_types/", page_size=1)
        except ApiError as error:
            # Paperless still starting: retry the whole run later.
            if error.status and error.status >= 500:
                raise Unreachable(str(error)) from None
            raise
        reported = self.last_api_version
        if not reported or not reported.isdigit() or int(reported) < API_VERSION:
            raise SystemExit(
                f"Paperless reports API version {reported!r}; version {API_VERSION} is required"
            )

    def upload(self, file_path, fields):
        """Stream a multipart upload from disk without buffering the file."""
        boundary = f"homelab07-{uuid.uuid4().hex}"
        parts = []
        for name, value in fields:
            if name == "document":
                continue
            parts.append(
                f"--{boundary}\r\nContent-Disposition: form-data; name=\"{name}\"\r\n\r\n"
                f"{value}\r\n".encode()
            )
        filename = dict(fields)["document"]
        file_header = (
            f"--{boundary}\r\nContent-Disposition: form-data; name=\"document\"; "
            f"filename=\"{filename}\"\r\nContent-Type: application/octet-stream\r\n\r\n"
        ).encode()
        closing = f"\r\n--{boundary}--\r\n".encode()
        length = sum(len(p) for p in parts) + len(file_header) + os.path.getsize(file_path) + len(closing)

        def body():
            yield from parts
            yield file_header
            with open(file_path, "rb") as handle:
                while chunk := handle.read(CHUNK_SIZE):
                    yield chunk
            yield closing

        return self.request(
            "POST", "/api/documents/post_document/", body=body(), timeout=300,
            headers={
                "Content-Type": f"multipart/form-data; boundary={boundary}",
                "Content-Length": str(length),
            },
        )


# -----------------------------------------------------------------------------
# Naming rules
# -----------------------------------------------------------------------------

DATE_DMY = re.compile(r"(?<!\d)(\d{2})-(\d{2})-(\d{4})(?!\d)")
DATE_YMD_COMPACT = re.compile(r"(?<!\d)(\d{8})(?!\d)")
FOLDER_ISO = re.compile(r"^(\d{4})-(\d{2})-(\d{2})$")
YEAR = re.compile(r"^\d{4}$")
UUID_LIKE = re.compile(r"^[0-9a-f]{8}[- ]?[0-9a-f]{4}[- ]?[0-9a-f]{4}[- ]?[0-9a-f]{4}[- ]?[0-9a-f]{12}$", re.I)


def valid_date(year, month, day, lower=dt.date(1900, 1, 1)):
    try:
        value = dt.date(int(year), int(month), int(day))
    except ValueError:
        return None
    return value if lower <= value <= dt.date.today() else None


def derive_date(stem, folders):
    """Return the document date following the Sprint 015 precedence, or None."""
    for match in DATE_DMY.finditer(stem):
        day, month, year = match.groups()
        if value := valid_date(year, month, day):
            return value
    # Rule 2 only accepts a delimited YYYYMMDD from 2000 onwards, so digits
    # inside longer identifiers or document numbers never become dates.
    for match in DATE_YMD_COMPACT.finditer(stem):
        digits = match.group(1)
        if value := valid_date(digits[:4], digits[4:6], digits[6:], lower=dt.date(2000, 1, 1)):
            return value
    for folder in reversed(folders):
        if match := FOLDER_ISO.match(folder):
            if value := valid_date(*match.groups()):
                return value
    for index in range(len(folders) - 1, 0, -1):
        month = MONTHS.get(fold(folders[index]))
        if month and YEAR.match(folders[index - 1]):
            if value := valid_date(folders[index - 1], month, 1):
                return value
    return None


class Namer:
    def __init__(self, category_map, personal_patterns):
        self.categories = {fold(key): nfc(value) for key, value in category_map.items()}
        self.patterns = [re.compile(pattern, re.IGNORECASE) for pattern in personal_patterns]

    def mask(self, text):
        for pattern in self.patterns:
            text = pattern.sub("***", text)
        return text

    def category(self, folders):
        for folder in reversed(folders):
            if value := self.categories.get(fold(folder)):
                return value
        return None

    def title(self, stem, category, date):
        """Return (title, needs_review)."""
        text = DATE_YMD_COMPACT.sub(" ", DATE_DMY.sub(" ", stem))
        bare = re.sub(r"[\s_\-.]+", "", text)
        generic = not bare or bare.isdigit() or UUID_LIKE.match(text.strip(" _-."))
        if not generic:
            text = re.sub(r"[_\-]+", " ", text)
            for pattern in self.patterns:
                text = pattern.sub(" ", text)
            text = re.sub(r"\s+", " ", text).strip(" .,;:()[]")
            generic = len(re.sub(r"[^\w]", "", text)) < 3 or text.replace(" ", "").isdigit()
        if not generic:
            return text, False
        parts = [DOCUMENT_TYPE, category, date.isoformat() if date else None]
        return " ".join(p for p in parts if p), True

    def describe(self, relative):
        """Return (date, category, title, needs_title_review) for a source path."""
        stem = os.path.splitext(os.path.basename(relative))[0]
        folders = relative.split("/")[:-1]
        date = derive_date(stem, folders)
        category = self.category(folders)
        return (date, category, *self.title(stem, category, date))


# -----------------------------------------------------------------------------
# PDF handling
# -----------------------------------------------------------------------------

QPDF_ENV = {"PATH": "/usr/local/bin:/usr/bin:/bin"}


def qpdf(arguments, password=None):
    return subprocess.run(
        ["qpdf", *arguments],
        input=(password + "\n").encode() if password is not None else None,
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        env=QPDF_ENV, check=False,
    ).returncode


def decrypt_if_needed(source, passwords):
    """Return (path_to_upload, temporary_path_or_None). Raises PermissionError."""
    status = qpdf(["--requires-password", source])
    if status == 2:  # not encrypted
        return source, None
    candidates = [""] if status == 3 else passwords
    for password in candidates:
        handle, target = tempfile.mkstemp(dir=WORK_DIR, suffix=".pdf")
        os.close(handle)
        if qpdf(["--password-file=-", "--decrypt", source, target], password) in (0, 3):
            return target, target
        os.unlink(target)
    raise PermissionError("no configured password opens the PDF")


def source_files():
    """Yield (absolute, relative) for every visible file in the source folder."""
    for root, directories, files in os.walk(SOURCE_DIR):
        directories[:] = sorted(d for d in directories if not d.startswith("."))
        for name in sorted(files):
            if name.startswith("."):
                continue
            absolute = os.path.join(root, name)
            yield absolute, nfc(os.path.relpath(absolute, SOURCE_DIR).replace(os.sep, "/"))


def source_snapshot():
    """Digest of (path, size, mtime) for every source file; cheap stat-only walk."""
    snapshot = hashlib.sha256()
    for absolute, relative in source_files():
        try:
            info = os.stat(absolute)
        except OSError:
            continue
        snapshot.update(f"{relative}\0{info.st_size}\0{info.st_mtime_ns}\n".encode())
    return snapshot.hexdigest()


def remember_snapshot():
    try:
        with open(SNAPSHOT_FILE, "w", encoding="utf-8") as handle:
            handle.write(source_snapshot())
    except OSError as error:
        log(f"WARNING: unable to record the source snapshot: {error.__class__.__name__}")


def read_snapshot():
    """Baseline of the last run, or None when no run recorded one or it was dropped."""
    try:
        with open(SNAPSHOT_FILE, encoding="utf-8") as handle:
            return handle.read().strip() or None
    except OSError:
        return None


def forget_snapshot():
    try:
        os.unlink(SNAPSHOT_FILE)
    except FileNotFoundError:
        pass


def digests(path):
    sha256, md5 = hashlib.sha256(), hashlib.md5(usedforsecurity=False)
    with open(path, "rb") as handle:
        while chunk := handle.read(CHUNK_SIZE):
            sha256.update(chunk)
            md5.update(chunk)
    return sha256.hexdigest(), md5.hexdigest()


# -----------------------------------------------------------------------------
# Metrics
# -----------------------------------------------------------------------------

def publish_metrics(status, started, counts):
    final = os.path.join(METRICS_DIR, METRICS_FILE)
    now = int(time.time())
    last_success = now if status == 1 else 0
    if status != 1 and os.path.exists(final):
        with open(final, encoding="utf-8") as handle:
            for line in handle:
                name, _, value = line.strip().partition(" ")
                if name == f"{METRICS_PREFIX}_last_success_timestamp_seconds" and value.isdigit():
                    last_success = int(value)
    lines = []
    for name, value, text in (
        ("last_run_timestamp_seconds", now, "Unix time of the latest completed attempt."),
        ("last_success_timestamp_seconds", last_success, "Unix time of the latest successful attempt."),
        ("last_status", status, "Status of the latest completed attempt, one for success."),
        ("last_duration_seconds", now - int(started), "Duration of the latest completed attempt."),
    ):
        lines += [f"# HELP {METRICS_PREFIX}_{name} {text}",
                  f"# TYPE {METRICS_PREFIX}_{name} gauge",
                  f"{METRICS_PREFIX}_{name} {value}"]
    lines += [f"# HELP {METRICS_PREFIX}_files Files per result in the latest completed attempt.",
              f"# TYPE {METRICS_PREFIX}_files gauge"]
    lines += [f'{METRICS_PREFIX}_files{{result="{key}"}} {counts.get(key, 0)}' for key in RESULTS]
    try:
        handle, temporary = tempfile.mkstemp(dir=METRICS_DIR, prefix=f".{METRICS_FILE}.")
        with os.fdopen(handle, "w", encoding="utf-8") as output:
            output.write("\n".join(lines) + "\n")
        os.chmod(temporary, 0o644)
        os.replace(temporary, final)
    except OSError as error:
        log(f"WARNING: unable to publish metrics: {error.__class__.__name__}")


# -----------------------------------------------------------------------------
# Synchronization
# -----------------------------------------------------------------------------

class Sync:
    def __init__(self, api, namer, passwords, task_timeout, settle_seconds):
        self.api = api
        self.namer = namer
        self.passwords = passwords
        self.task_timeout = task_timeout
        self.settle_seconds = settle_seconds
        self.counts = dict.fromkeys(RESULTS, 0)

    def resolve_model(self):
        def required(path, name):
            item = self.api.find_by_name(path, name)
            if not item:
                raise SystemExit(f"Missing Paperless object {name!r}; run model-init first")
            return item["id"]

        self.type_id = required("/api/document_types/", DOCUMENT_TYPE)
        self.tags = {name: required("/api/tags/", name)
                     for name in (TAG_MEDICAL, TAG_REVIEW_DATE, TAG_REVIEW_TITLE)}
        self.category_tags = {}
        for category in set(self.namer.categories.values()):
            self.category_tags[category] = required("/api/tags/", category)
        self.field_path = required("/api/custom_fields/", FIELD_PATH)
        self.field_hash = required("/api/custom_fields/", FIELD_HASH)

    def existing(self, relative):
        """Return (found, stored_hash, user_can_change) for this source path."""
        query = json.dumps([self.field_path, "exact", relative])
        for document in self.api.results("/api/documents/", custom_field_query=query, page_size=5):
            values = {f.get("field"): f.get("value") for f in document.get("custom_fields", [])}
            if values.get(self.field_path) == relative:
                return True, values.get(self.field_hash), document.get("user_can_change")
        return False, None, None

    def is_duplicate(self, upload_path):
        """True only when Paperless confirms an identical stored file."""
        for checksum in digests(upload_path):
            for document in self.api.results("/api/documents/", checksum__iexact=checksum, page_size=3):
                metadata = self.api.get(f"/api/documents/{document['id']}/metadata/") or {}
                if str(metadata.get("original_checksum", "")).lower() == checksum:
                    return True
        return False

    def wait_for_task(self, task_id):
        """Poll an API v10 task: lowercase status, related_document_ids and result_data."""
        deadline = time.monotonic() + self.task_timeout
        while time.monotonic() < deadline:
            data = self.api.get("/api/tasks/", task_id=task_id)
            tasks = data.get("results", []) if isinstance(data, dict) else (data or [])
            if tasks:
                task = tasks[0]
                status = str(task.get("status", "")).lower()
                result = task.get("result_data") or {}
                if status == "success":
                    ids = task.get("related_document_ids") or []
                    document_id = result.get("document_id") or (ids[0] if ids else None)
                    if document_id is None:
                        return "failure", None
                    return "success", document_id
                if status in ("failure", "revoked"):
                    if result.get("duplicate_of"):
                        return "duplicate", None
                    return "failure", None
            time.sleep(5)
        return "timeout", None

    def verify_document(self, document_id):
        """post_document makes the uploader the owner; the workflow must reassign it."""
        document = self.api.get(f"/api/documents/{document_id}/")
        if not document or document.get("owner") is None:
            raise ApiError("uploaded exam has no owner; check the ownership workflow")
        if document.get("user_can_change") is not False:
            raise ApiError("sync-medico still owns the uploaded exam; check the ownership workflow")
        fields = {f.get("field") for f in document.get("custom_fields", [])}
        if self.field_path not in fields or self.field_hash not in fields:
            raise ApiError("custom fields were not stored with the upload")

    def process(self, absolute, relative, original_hash, ident):
        extension = os.path.splitext(relative)[1]
        if extension.lower() not in SUPPORTED_EXTENSIONS:
            self.counts["unsupported"] += 1
            log(f"UNSUPPORTED {ident}")
            return
        found, stored_hash, can_change = self.existing(relative)
        if found:
            # Re-checked on every run: sync-medico must never own an exam.
            if can_change is True:
                self.counts["failed"] += 1
                log(f"ERROR sync-medico still owns an uploaded exam; check the ownership workflow: {ident}")
            elif stored_hash == original_hash:
                self.counts["skipped"] += 1
            else:
                self.counts["modified"] += 1
                log(f"WARNING modified after upload, not re-uploaded: {ident}")
            return

        temporary = None
        try:
            upload_path = absolute
            if extension.lower() == ".pdf":
                try:
                    upload_path, temporary = decrypt_if_needed(absolute, self.passwords)
                except PermissionError:
                    self.counts["encrypted_no_password"] += 1
                    log(f"ERROR encrypted PDF without a working password: {ident}")
                    return
            if self.is_duplicate(upload_path):
                self.counts["duplicate"] += 1
                log(f"WARNING duplicate content already in Paperless: {ident}")
                return

            date, category, title, review_title = self.namer.describe(relative)
            tags = [self.tags[TAG_MEDICAL]]
            if category:
                tags.append(self.category_tags[category])
            if date is None:
                tags.append(self.tags[TAG_REVIEW_DATE])
            if review_title:
                tags.append(self.tags[TAG_REVIEW_TITLE])

            fields = [
                ("document", f"{title}{extension.lower()}".replace('"', "")),
                ("title", title),
                ("document_type", self.type_id),
                ("custom_fields", json.dumps({str(self.field_path): relative,
                                              str(self.field_hash): original_hash})),
            ]
            fields += [("tags", tag) for tag in tags]
            if date:
                fields.append(("created", date.isoformat()))

            task_id = self.api.upload(upload_path, fields)
            outcome, document_id = self.wait_for_task(str(task_id).strip('"'))
            if outcome == "success":
                self.verify_document(document_id)
                self.counts["uploaded"] += 1
                log(f"UPLOADED {ident}")
            elif outcome == "duplicate":
                self.counts["duplicate"] += 1
                log(f"WARNING Paperless rejected a duplicate: {ident}")
            else:
                self.counts["failed"] += 1
                log(f"ERROR upload {outcome}: {ident}")
        finally:
            if temporary and os.path.exists(temporary):
                os.unlink(temporary)

    def run(self):
        self.api.check_version()
        self.resolve_model()
        for absolute, relative in source_files():
            ident = self.namer.mask(relative)
            try:
                # A file still being copied is left for the next run. Only
                # ctime is used: the copying client sets mtime, which may be in
                # the past or the future, but every write updates ctime. A
                # ctime ahead of the clock never defers, so it cannot loop.
                age = time.time() - os.stat(absolute).st_ctime
                if 0 <= age < self.settle_seconds:
                    self.counts["deferred"] += 1
                    log(f"DEFERRED recently changed, retried after it settles: {ident}")
                    continue
                original_hash, _ = digests(absolute)
                ident = f"{ident}#{original_hash[:12]}"
                self.process(absolute, relative, original_hash, ident)
            except OSError as error:
                self.counts["failed"] += 1
                log(f"ERROR unreadable {ident}: {error.__class__.__name__}")
            except ApiError as error:
                # Includes HTTP 5xx: only this file fails; the run continues.
                self.counts["failed"] += 1
                log(f"ERROR {ident}: {self.namer.mask(str(error))}")
        if self.counts["deferred"]:
            # Without a baseline the watcher treats the folder as changed and
            # starts another run once it is stable.
            forget_snapshot()
        summary = " ".join(f"{key}={value}" for key, value in self.counts.items())
        log(f"SUMMARY {summary}")
        return self.counts["failed"] == 0 and self.counts["encrypted_no_password"] == 0


def command_sync():
    started = time.time()
    os.makedirs(WORK_DIR, exist_ok=True)
    lock = open(LOCK_FILE, "w")
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        lock.close()
        log("Another sync run holds the lock; nothing to do.")
        return EXIT_LOCKED

    # Baseline for wait-change, taken before the walk so that changes made
    # during this run start another one.
    remember_snapshot()

    # Secrets are read once and removed from the process environment.
    token = os.environ.pop("PAPERLESS_SYNC_TOKEN", "")
    passwords = json_env("PDF_PASSWORDS", [])
    os.environ.pop("PDF_PASSWORDS", None)
    counts = {}
    try:
        if not token:
            raise SystemExit("PAPERLESS_SYNC_TOKEN is required")
        if not isinstance(passwords, list) or not all(isinstance(p, str) for p in passwords):
            raise SystemExit("PDF_PASSWORDS must be a JSON list of strings")
        namer = Namer(json_env("SYNC_CATEGORY_MAP", {}), json_env("SYNC_PERSONAL_PATTERNS", []))
        api = Paperless(os.environ.get("PAPERLESS_INTERNAL_URL", "http://homelab07-paperless-ngx:8000"), token)
        api.redact = namer.mask
        sync = Sync(api, namer, passwords, int(os.environ.get("SYNC_TASK_TIMEOUT", "900")),
                    int_env("SYNC_SETTLE_SECONDS", 30))
        counts = sync.counts
        ok = sync.run()
        publish_metrics(1 if ok else 0, started, counts)
        return EXIT_OK if ok else EXIT_FAILED
    except Unreachable as error:
        log(f"ERROR Paperless unreachable: {error}")
        publish_metrics(0, started, counts)
        return EXIT_UNREACHABLE
    except (SystemExit, ApiError, ValueError, re.error) as error:
        log(f"ERROR {error}")
        publish_metrics(0, started, counts)
        return EXIT_FAILED


# -----------------------------------------------------------------------------
# Data model (administrator token, one-off)
# -----------------------------------------------------------------------------

def ensure(api, path, name, payload):
    item = api.find_by_name(path, name)
    if item:
        log(f"exists  {path} {name}")
        return item["id"]
    created = api.post(path, payload)
    log(f"created {path} {name}")
    return created["id"]


def ensure_shared(api, path, name, payload, sharing):
    """Create or reconcile an owned object: exam owner + view for sync-medico."""
    item = api.find_by_name(path, name)
    if item:
        api.request("PATCH", f"{path}{item['id']}/", body=sharing)
        log(f"reconciled {path} {name} owner and permissions")
        return item["id"]
    created = api.post(path, {**payload, **sharing})
    log(f"created {path} {name}")
    return created["id"]


def reader_usernames(owner_username):
    readers = json_env("SYNC_READER_USERNAMES", [])
    if not isinstance(readers, list) or not all(isinstance(r, str) and r.strip() for r in readers):
        raise SystemExit("SYNC_READER_USERNAMES must be a JSON list of user names")
    readers = sorted({r.strip() for r in readers})
    # A reader is reduced to view-only rights: never the owner or the uploader.
    if any(r.casefold() in (owner_username.casefold(), SYNC_USERNAME) for r in readers):
        raise SystemExit("SYNC_READER_USERNAMES must not include the exam owner or sync-medico")
    return readers


def grant_readers(api, reader_ids, medical_tag):
    """Add view for read-only users without removing existing permissions or owners."""
    view = {
        "view": {"users": reader_ids, "groups": []},
        "change": {"users": [], "groups": []},
    }
    for object_type in ("tags", "correspondents"):
        ids = [item["id"] for item in api.all_results(f"/api/{object_type}/")]
        if ids:
            api.post("/api/bulk_edit_objects/", {
                "objects": ids,
                "object_type": object_type,
                "operation": "set_permissions",
                "permissions": view,
                "merge": True,
            })
        log(f"granted read-only view on {len(ids)} {object_type}")
    documents = [d["id"] for d in api.all_results("/api/documents/", tags__id__all=medical_tag, fields="id")]
    if documents:
        api.post("/api/documents/bulk_edit/", {
            "documents": documents,
            "method": "set_permissions",
            "parameters": {"set_permissions": view, "merge": True},
        })
    log(f"granted read-only view on {len(documents)} exams")


def command_model_init():
    owner_username = os.environ.get("SYNC_OWNER_USERNAME", "").strip()
    if not owner_username:
        raise SystemExit("SYNC_OWNER_USERNAME is required")
    readers = reader_usernames(owner_username)
    category_map = {key: nfc(value) for key, value in json_env("SYNC_CATEGORY_MAP", {}).items()}
    prompt = "Temporary Paperless administrator token: "
    admin_token = getpass.getpass(prompt) if sys.stdin.isatty() else sys.stdin.readline().strip()
    if not admin_token:
        raise SystemExit("An administrator token is required on stdin")

    api = Paperless(os.environ.get("PAPERLESS_INTERNAL_URL", "http://homelab07-paperless-ngx:8000"), admin_token)
    api.check_version()

    owner = api.find_by_name("/api/users/", owner_username, field="username")
    if not owner:
        raise SystemExit("SYNC_OWNER_USERNAME does not match a Paperless user")
    # Resolve every read-only user before the first write: a missing one stops
    # model-init without changes. model-init never creates them.
    reader_ids = []
    for name in readers:
        reader = api.find_by_name("/api/users/", name, field="username")
        if not reader:
            raise SystemExit(f"Read-only user {name!r} does not exist in Paperless; create it first")
        reader_ids.append(reader["id"])

    sync_user = api.find_by_name("/api/users/", SYNC_USERNAME, field="username")
    if sync_user:
        sync_user_id = sync_user["id"]
        # Reconcile privileges so drift (for example manual staff rights) is reverted.
        api.request("PATCH", f"/api/users/{sync_user_id}/", body={
            "is_staff": False,
            "is_superuser": False,
            "user_permissions": SYNC_PERMISSIONS,
        })
        log(f"reconciled /api/users/ {SYNC_USERNAME} permissions")
    else:
        sync_user_id = api.post("/api/users/", {
            "username": SYNC_USERNAME,
            # Random and never stored: the account authenticates by token only.
            "password": secrets.token_urlsafe(48),
            "is_staff": False,
            "is_superuser": False,
            "is_active": True,
            "user_permissions": SYNC_PERMISSIONS,
        })["id"]
        log(f"created /api/users/ {SYNC_USERNAME}")

    for name, reader_id in zip(readers, reader_ids):
        api.request("PATCH", f"/api/users/{reader_id}/", body={
            "is_staff": False,
            "is_superuser": False,
            "user_permissions": READER_PERMISSIONS,
        })
        log(f"reconciled /api/users/ {name} read-only permissions")

    # Types and tags are owned objects in Paperless: global view permission is
    # not enough. The exam owner owns them; sync-medico and the read-only users
    # get view access.
    viewers = [sync_user_id, *reader_ids]
    sharing = {
        "owner": owner["id"],
        "set_permissions": {
            "view": {"users": viewers, "groups": []},
            "change": {"users": [], "groups": []},
        },
    }
    no_matching = {"matching_algorithm": MATCH_NONE, "match": ""}
    type_id = ensure_shared(api, "/api/document_types/", DOCUMENT_TYPE,
                            {"name": DOCUMENT_TYPE, **no_matching}, sharing)
    medical_tag = None
    for name in (TAG_MEDICAL, TAG_REVIEW_DATE, TAG_REVIEW_TITLE, *sorted(set(category_map.values()))):
        tag_id = ensure_shared(api, "/api/tags/", name,
                               {"name": name, "is_inbox_tag": False, **no_matching}, sharing)
        if name == TAG_MEDICAL:
            medical_tag = tag_id
    for name in (FIELD_PATH, FIELD_HASH):
        ensure(api, "/api/custom_fields/", name, {"name": name, "data_type": "string"})

    existing_workflow = api.find_by_name("/api/workflows/", WORKFLOW_NAME)
    if existing_workflow:
        # Nested workflow updates are not reconciled automatically: verify the
        # contract and stop on drift so the operator recreates it deliberately.
        triggers = existing_workflow.get("triggers", [])
        actions = existing_workflow.get("actions", [])
        trigger_ok = any(
            t.get("type") == TRIGGER_DOCUMENT_ADDED
            and medical_tag in (t.get("filter_has_tags") or [])
            and SOURCE_API_UPLOAD in (t.get("sources") or [])
            for t in triggers
        )
        action_ok = any(
            a.get("assign_owner") == owner["id"]
            and set(viewers) <= set(a.get("assign_view_users") or [])
            for a in actions
        )
        if not (existing_workflow.get("enabled") and trigger_ok and action_ok):
            raise SystemExit(
                f"Workflow {WORKFLOW_NAME!r} differs from the Sprint 015 contract; "
                "delete it in Paperless and run model-init again"
            )
        log(f"verified /api/workflows/ {WORKFLOW_NAME}")
    else:
        create_workflow(api, owner["id"], viewers, type_id, medical_tag)

    if reader_ids:
        grant_readers(api, reader_ids, medical_tag)
    log("Data model ready. Revoke the temporary administrator token now.")
    return EXIT_OK


def create_workflow(api, owner_id, viewers, type_id, medical_tag):
    no_matching = {"matching_algorithm": MATCH_NONE, "match": ""}
    ensure(api, "/api/workflows/", WORKFLOW_NAME, {
        "name": WORKFLOW_NAME,
        "order": 0,
        "enabled": True,
        "triggers": [{
            "type": TRIGGER_DOCUMENT_ADDED,
            "sources": [SOURCE_API_UPLOAD],
            "filter_has_tags": [medical_tag],
            **no_matching,
        }],
        "actions": [{
            "type": ACTION_ASSIGNMENT,
            "assign_document_type": type_id,
            "assign_owner": owner_id,
            "assign_view_users": viewers,
        }],
    })


def command_next_delay():
    hour = int(os.environ.get("SYNC_HOUR", "3"))
    now = dt.datetime.now()
    target = now.replace(hour=hour, minute=0, second=0, microsecond=0)
    if target <= now:
        target += dt.timedelta(days=1)
    print(int((target - now).total_seconds()))
    return EXIT_OK


def command_wait_ready():
    """Wait until Paperless answers HTTP before the first run after a start."""
    api = Paperless(os.environ.get("PAPERLESS_INTERNAL_URL", "http://homelab07-paperless-ngx:8000"), None)
    deadline = time.monotonic() + int(os.environ.get("SYNC_STARTUP_WAIT", "600"))
    while time.monotonic() < deadline:
        try:
            api.get("/api/")
            return EXIT_OK
        except ApiError as error:
            if error.status and error.status < 500:
                return EXIT_OK  # Answering (for example 401): ready.
        except Unreachable:
            pass
        time.sleep(15)
    log("Paperless did not answer within SYNC_STARTUP_WAIT; starting anyway.")
    return EXIT_OK


def command_wait_change(seconds):
    """Return after a stable source change or when SECONDS elapse, whichever is first.

    The folder is polled every SYNC_WATCH_INTERVAL seconds with a stat-only walk.
    A snapshot that differs from the last run's baseline must stay unchanged for
    SYNC_SETTLE_SECONDS, so a copy in progress or a batch of files starts one run.
    """
    deadline = time.monotonic() + seconds
    interval = int_env("SYNC_WATCH_INTERVAL", 30)
    settle = int_env("SYNC_SETTLE_SECONDS", 30)
    if interval <= 0:  # Watcher disabled: daily run only.
        time.sleep(max(0, seconds))
        return EXIT_OK
    pending, since = None, None
    while (remaining := deadline - time.monotonic()) > 0:
        time.sleep(min(interval, remaining))
        current = source_snapshot()
        # Re-read every poll: a concurrent manual run may have replaced the
        # baseline or dropped it after deferring files.
        if current == read_snapshot():
            pending = None
        elif current != pending:
            pending, since = current, time.monotonic()
        elif time.monotonic() - since >= settle:
            log("Source folder changed and settled; starting sync.")
            return EXIT_OK
    return EXIT_OK


def command_preview():
    """Show what a sync would derive, before the first load. Nothing is uploaded."""
    namer = Namer(json_env("SYNC_CATEGORY_MAP", {}), json_env("SYNC_PERSONAL_PATTERNS", []))
    for _, relative in source_files():
        extension = os.path.splitext(relative)[1].lower()
        if extension not in SUPPORTED_EXTENSIONS:
            print(f"UNSUPPORTED {namer.mask(relative)}")
            continue
        date, category, title, review_title = namer.describe(relative)
        review = [tag for tag, flag in ((TAG_REVIEW_DATE, date is None),
                                        (TAG_REVIEW_TITLE, review_title)) if flag]
        print(" | ".join((
            namer.mask(relative),
            date.isoformat() if date else "-",
            category or "-",
            title,
            ",".join(review) or "-",
        )))
    return EXIT_OK


def main(arguments):
    commands = {
        "sync": command_sync,
        "preview": command_preview,
        "model-init": command_model_init,
        "next-delay": command_next_delay,
        "wait-ready": command_wait_ready,
        "wait-change": command_wait_change,
    }
    name, rest = (arguments[0], arguments[1:]) if arguments else (None, [])
    if name == "wait-change" and len(rest) == 1 and rest[0].isdigit():
        rest = [int(rest[0])]
    elif name not in commands or rest or name == "wait-change":
        print(__doc__, file=sys.stderr)
        return 2
    try:
        return commands[name](*rest)
    except SystemExit as error:
        if isinstance(error.code, str):
            log(f"ERROR {error.code}")
            return EXIT_FAILED
        raise


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
