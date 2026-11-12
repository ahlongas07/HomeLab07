#!/usr/bin/env python3
"""HomeLab07 quote archive synchronization for Paperless-ngx (Sprint 020).

Commands:
  sync                 archive new quote PDFs from the read-only quotes folder
  preview              print the validation result and metadata of every file;
                       no Paperless access, nothing uploaded
  check-model          verify that the document type, tags and custom field exist
                       and that the type and tags belong to the sync user; creates nothing
  next-delay           print seconds until the next scheduled run
  wait-ready           wait until Paperless answers HTTP (used once at start-up)
  wait-change SECONDS  wait up to SECONDS for a stable change in the quotes folder

Exit status of sync: 0 every file handled, 3 another run holds the lock,
4 retry after QUOTE_RETRY_SECONDS (an upload is unconfirmed or Paperless
answered an error), 75 Paperless unreachable. A failed run keeps the pending
and unresolved values of the last completed run in the metrics.

Only the Python standard library is used.
"""

import datetime as dt
import fcntl
import hashlib
import http.client
import json
import os
import re
import subprocess
import sys
import tempfile
import time
import unicodedata
import urllib.parse
import uuid

# -----------------------------------------------------------------------------
# Contract constants (Sprint 020)
# -----------------------------------------------------------------------------

API_VERSION = 10
DOCUMENT_TYPE = "Cotización"
TAG_JUANCHOAI = "juanchoai"
TAG_FINAL = "cotizacion-final"
FIELD_WORK_ITEM = "Work Item"

QUOTES_DIR = "/quotes"
METRICS_DIR = "/metrics"
WORK_DIR = "/run/sync"
ACK_FILE = "/acknowledged"
LOCK_FILE = os.path.join(WORK_DIR, "sync.lock")
SNAPSHOT_FILE = os.path.join(WORK_DIR, "snapshot")
STATE_FILE = os.path.join(WORK_DIR, "state.json")
METRICS_FILE = "paperless-quote-sync.prom"
METRICS_PREFIX = "homelab07_paperless_quote_sync"

MAX_SIZE = 20 * 1024 * 1024
CHUNK_SIZE = 1024 * 1024
CONFIRM_POLL_SECONDS = 5

# <uuid>__<external_id>__<YYYY-MM-DD>.pdf with exactly two "__" separators:
# the identifier charset excludes "_", so the name splits unambiguously.
FILE_NAME = re.compile(
    r"^(?P<uuid>[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})"
    r"__(?P<external_id>[A-Za-z0-9-]{1,64})"
    r"__(?P<year>\d{4})-(?P<month>\d{2})-(?P<day>\d{2})\.pdf$"
)
YEAR_FOLDER = re.compile(r"^\d{4}$")

EXIT_OK = 0
EXIT_FAILED = 1
EXIT_LOCKED = 3
EXIT_RETRY = 4
EXIT_UNREACHABLE = 75

RESULTS = ("uploaded", "skipped", "rejected", "conflict", "failure",
           "pending", "deferred", "acknowledged")
UNRESOLVED_REASONS = ("rejected", "conflict", "failure")
PENDING_RESULTS = ("pending", "failure")


class Unreachable(Exception):
    """Paperless could not be reached; the run should be retried soon."""


class ApiError(Exception):
    def __init__(self, message, status=None):
        super().__init__(message)
        self.status = status


class Rejected(Exception):
    """The file violates the contract; it is never uploaded."""


def log(message):
    print(f"{dt.datetime.now().isoformat(timespec='seconds')} {message}", flush=True)


def nfc(value):
    return unicodedata.normalize("NFC", value)


def int_env(name, default):
    try:
        return int(os.environ.get(name, "").strip() or default)
    except ValueError:
        raise SystemExit(f"{name} must be an integer") from None


def paperless_url():
    return os.environ.get("PAPERLESS_INTERNAL_URL", "http://homelab07-paperless-ngx:8000")


# -----------------------------------------------------------------------------
# Paperless API client (same contract as the medical sync, Sprint 015)
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
        self.last_api_version = None

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
            excerpt = payload[:300].decode("utf-8", "replace")
            raise ApiError(f"{method} {path}: HTTP {response.status}: {excerpt}", response.status)
        self.last_api_version = response.getheader("X-Api-Version")
        if not payload:
            return None
        return json.loads(payload)

    def get(self, path, **query):
        return self.request("GET", path, query=query or None)

    def results(self, path, **query):
        query.setdefault("page_size", 100)
        data = self.get(path, **query)
        return data.get("results", []) if isinstance(data, dict) else (data or [])

    def all_results(self, path, **query):
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

    def find_by_name(self, path, name, accept=lambda item: True):
        wanted = nfc(name).casefold()

        def match(items):
            for item in items:
                if nfc(str(item.get("name", ""))).casefold() == wanted and accept(item):
                    return item
            return None

        if item := match(self.results(path, name__iexact=name)):
            return item
        # The server compares raw strings; a name stored in another Unicode
        # form is only found locally.
        return match(self.all_results(path))

    def check_version(self):
        try:
            self.get("/api/document_types/", page_size=1)
        except ApiError as error:
            if error.status and error.status >= 500:
                raise Unreachable(str(error)) from None
            raise
        reported = self.last_api_version
        if not reported or not reported.isdigit() or int(reported) < API_VERSION:
            raise SystemExit(
                f"Paperless reports API version {reported!r}; version {API_VERSION} is required"
            )

    def own_user_id(self):
        data = self.get("/api/ui_settings/") or {}
        user_id = (data.get("user") or {}).get("id")
        if not isinstance(user_id, int):
            raise SystemExit("Paperless did not report the id of the token user")
        return user_id

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
            f"filename=\"{filename}\"\r\nContent-Type: application/pdf\r\n\r\n"
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
# Contract validation
# -----------------------------------------------------------------------------

def parse_name(relative):
    """Return (uuid, external_id, date) for `<YYYY>/<name>.pdf`, or raise Rejected."""
    parts = relative.split("/")
    if len(parts) != 2:
        raise Rejected("not directly inside a year folder")
    folder, name = parts
    if not YEAR_FOLDER.match(folder):
        raise Rejected("folder is not a four-digit year")
    match = FILE_NAME.match(name)
    if not match:
        raise Rejected("name is not <uuid>__<external_id>__<YYYY-MM-DD>.pdf")
    try:
        date = dt.date(int(match["year"]), int(match["month"]), int(match["day"]))
    except ValueError:
        raise Rejected("date is not a valid calendar date") from None
    if match["year"] != folder:
        raise Rejected("year folder differs from the date in the name")
    return match["uuid"], match["external_id"], date


QPDF_ENV = {"PATH": "/usr/local/bin:/usr/bin:/bin"}


def pdf_encrypted(path):
    """True when the PDF needs a password or has encryption; None when unreadable."""
    status = subprocess.run(
        ["qpdf", "--requires-password", path],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, env=QPDF_ENV, check=False,
    ).returncode
    if status == 2:
        return False
    if status in (0, 3):
        return True
    return None


def validate_pdf(absolute):
    """Raise Rejected unless the file is an unencrypted PDF of 20 MB or less."""
    size = os.path.getsize(absolute)
    if size > MAX_SIZE:
        raise Rejected("larger than 20 MB")
    with open(absolute, "rb") as handle:
        head = handle.read(1024)
    if b"%PDF-" not in head:
        raise Rejected("not a PDF")
    encrypted = pdf_encrypted(absolute)
    if encrypted is None:
        raise Rejected("PDF cannot be read")
    if encrypted:
        raise Rejected("encrypted PDF")


def sha256_of(path):
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        while chunk := handle.read(CHUNK_SIZE):
            digest.update(chunk)
    return digest.hexdigest()


# -----------------------------------------------------------------------------
# Quotes folder
# -----------------------------------------------------------------------------

def quote_files():
    """Yield (absolute, relative) for every visible PDF-named file in the folder.

    Files whose name starts with "." (the API's temporary files) or does not end
    in ".pdf" are ignored, as the contract requires.
    """
    for root, directories, files in os.walk(QUOTES_DIR):
        directories[:] = sorted(d for d in directories if not d.startswith("."))
        for name in sorted(files):
            if name.startswith(".") or not name.endswith(".pdf"):
                continue
            absolute = os.path.join(root, name)
            yield absolute, nfc(os.path.relpath(absolute, QUOTES_DIR).replace(os.sep, "/"))


def folder_snapshot():
    snapshot = hashlib.sha256()
    for absolute, relative in quote_files():
        try:
            info = os.stat(absolute)
        except OSError:
            continue
        snapshot.update(f"{relative}\0{info.st_size}\0{info.st_mtime_ns}\n".encode())
    return snapshot.hexdigest()


def remember_snapshot():
    try:
        with open(SNAPSHOT_FILE, "w", encoding="utf-8") as handle:
            handle.write(folder_snapshot())
    except OSError as error:
        log(f"WARNING: unable to record the folder snapshot: {error.__class__.__name__}")


def read_snapshot():
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


# -----------------------------------------------------------------------------
# Acknowledgement list and watcher state
# -----------------------------------------------------------------------------

def read_acknowledged():
    """Set of "<relative path> <sha256>" entries; re-read on every run."""
    entries = set()
    if not os.path.exists(ACK_FILE):
        return entries
    if not os.path.isfile(ACK_FILE):
        log("WARNING acknowledgement list is not a file; no file is acknowledged")
        return entries
    try:
        with open(ACK_FILE, encoding="utf-8") as handle:
            for number, line in enumerate(handle, 1):
                text = line.strip()
                if not text or text.startswith("#"):
                    continue
                relative, _, digest = text.rpartition(" ")
                if not relative or not re.fullmatch(r"[0-9a-f]{64}", digest):
                    log(f"WARNING acknowledgement list line {number} ignored: expected '<relative path> <sha256>'")
                    continue
                entries.add(f"{nfc(relative)} {digest}")
    except OSError as error:
        log(f"WARNING acknowledgement list unreadable: {error.__class__.__name__}")
    return entries


def load_state():
    try:
        with open(STATE_FILE, encoding="utf-8") as handle:
            state = json.load(handle)
        if isinstance(state, dict):
            state.setdefault("attempts", {})
            state.setdefault("metrics", {})
            return state
    except (OSError, ValueError):
        pass
    return {"attempts": {}, "metrics": {}}


def save_state(state):
    try:
        os.makedirs(WORK_DIR, exist_ok=True)
        handle, temporary = tempfile.mkstemp(dir=WORK_DIR, prefix=".state.")
        with os.fdopen(handle, "w", encoding="utf-8") as output:
            json.dump(state, output)
        os.replace(temporary, STATE_FILE)
    except OSError as error:
        log(f"WARNING: unable to save the watcher state: {error.__class__.__name__}")


# -----------------------------------------------------------------------------
# Metrics
# -----------------------------------------------------------------------------

def publish_metrics(metrics):
    gauges = [
        ("last_run_timestamp_seconds", "Unix time of the latest completed attempt."),
        ("last_success_timestamp_seconds", "Unix time of the latest successful attempt."),
        ("last_status", "Status of the latest completed attempt, one for success."),
        ("last_duration_seconds", "Duration of the latest completed attempt."),
        ("heartbeat_timestamp_seconds", "Unix time of the latest watcher heartbeat."),
        ("pending_files", "Valid files not yet confirmed in Paperless, acknowledged ones excluded."),
        ("oldest_pending_timestamp_seconds", "Unix time the oldest pending file reached the folder, zero when none."),
        ("oldest_pending_age_seconds", "Age of the oldest pending file at the latest attempt, zero when none."),
    ]
    lines = []
    for name, text in gauges:
        lines += [f"# HELP {METRICS_PREFIX}_{name} {text}",
                  f"# TYPE {METRICS_PREFIX}_{name} gauge",
                  f"{METRICS_PREFIX}_{name} {int(metrics.get(name, 0))}"]
    files = metrics.get("files", {})
    lines += [f"# HELP {METRICS_PREFIX}_files Files per result in the latest completed attempt.",
              f"# TYPE {METRICS_PREFIX}_files gauge"]
    lines += [f'{METRICS_PREFIX}_files{{result="{key}"}} {int(files.get(key, 0))}' for key in RESULTS]
    unresolved = metrics.get("unresolved", {})
    lines += [f"# HELP {METRICS_PREFIX}_unresolved Files awaiting review, acknowledged ones excluded.",
              f"# TYPE {METRICS_PREFIX}_unresolved gauge"]
    lines += [f'{METRICS_PREFIX}_unresolved{{reason="{key}"}} {int(unresolved.get(key, 0))}'
              for key in UNRESOLVED_REASONS]
    final = os.path.join(METRICS_DIR, METRICS_FILE)
    try:
        handle, temporary = tempfile.mkstemp(dir=METRICS_DIR, prefix=f".{METRICS_FILE}.")
        with os.fdopen(handle, "w", encoding="utf-8") as output:
            output.write("\n".join(lines) + "\n")
        os.chmod(temporary, 0o644)
        os.replace(temporary, final)
    except OSError as error:
        log(f"WARNING: unable to publish metrics: {error.__class__.__name__}")


def refresh_heartbeat():
    """Keep the heartbeat metric fresh between runs; other values are unchanged."""
    state = load_state()
    state["metrics"]["heartbeat_timestamp_seconds"] = int(time.time())
    save_state(state)
    publish_metrics(state["metrics"])


def touch_heartbeat():
    try:
        with open(os.path.join(WORK_DIR, "heartbeat"), "w", encoding="utf-8") as handle:
            handle.write(f"{int(time.time())}\n")
    except OSError:
        pass


_heartbeat_refreshed = time.monotonic()


def heartbeat():
    """Touch the container heartbeat and refresh the metric every QUOTE_HEARTBEAT_SECONDS.

    Called while waiting for changes and while a confirmation polls Paperless,
    so a long run with several unconfirmed files never looks like a down
    container.
    """
    global _heartbeat_refreshed
    touch_heartbeat()
    if time.monotonic() - _heartbeat_refreshed >= int_env("QUOTE_HEARTBEAT_SECONDS", 300):
        refresh_heartbeat()
        _heartbeat_refreshed = time.monotonic()


# -----------------------------------------------------------------------------
# Synchronization
# -----------------------------------------------------------------------------

class Sync:
    def __init__(self, api, state, acknowledged, confirm_timeout, max_attempts, settle_seconds):
        self.api = api
        self.state = state
        self.acknowledged = acknowledged
        self.confirm_timeout = confirm_timeout
        self.max_attempts = max_attempts
        self.settle_seconds = settle_seconds
        self.counts = dict.fromkeys(RESULTS, 0)
        self.pending_since = []
        self.seen = set()

    def resolve_model(self):
        """Resolve the contract objects owned by the sync user; nothing is created."""
        me = self.api.own_user_id()

        def owned(path, name):
            item = self.api.find_by_name(path, name, accept=lambda i: i.get("owner") == me)
            if not item:
                raise SystemExit(f"Missing Paperless object {name!r} owned by the sync user")
            return item["id"]

        self.type_id = owned("/api/document_types/", DOCUMENT_TYPE)
        self.tag_ids = [owned("/api/tags/", TAG_JUANCHOAI), owned("/api/tags/", TAG_FINAL)]
        field = self.api.find_by_name("/api/custom_fields/", FIELD_WORK_ITEM)
        if not field:
            raise SystemExit(f"Missing Paperless custom field {FIELD_WORK_ITEM!r}")
        self.field_id = field["id"]

    def documents_for(self, work_item):
        """Return [(document_id, original_checksum)] for a Work Item value."""
        query = json.dumps([self.field_id, "exact", work_item])
        found = []
        for document in self.api.results("/api/documents/", custom_field_query=query,
                                         fields="id,custom_fields", page_size=10):
            values = {f.get("field"): f.get("value") for f in document.get("custom_fields", [])}
            if values.get(self.field_id) != work_item:
                continue
            metadata = self.api.get(f"/api/documents/{document['id']}/metadata/") or {}
            found.append((document["id"], str(metadata.get("original_checksum", "")).lower()))
        return found

    def confirm(self, work_item, digest):
        """Poll the Work Item search until the document appears or the timeout expires."""
        deadline = time.monotonic() + self.confirm_timeout
        while True:
            documents = self.documents_for(work_item)
            if len(documents) == 1 and documents[0][1] == digest:
                return "uploaded"
            if documents:
                return "conflict"
            if time.monotonic() >= deadline:
                return "timeout"
            heartbeat()
            time.sleep(CONFIRM_POLL_SECONDS)

    def process(self, absolute, relative, digest):
        """Return the outcome for one file following the QS-R4 decision table."""
        key = f"{relative} {digest}"
        self.seen.add(key)
        if key in self.acknowledged:
            return "acknowledged"
        try:
            work_item, external_id, date = parse_name(relative)
            validate_pdf(absolute)
        except Rejected as reason:
            log(f"REJECTED {relative}: {reason}")
            return "rejected"

        documents = self.documents_for(work_item)
        if len(documents) == 1 and documents[0][1] == digest:
            self.state["attempts"].pop(key, None)
            return "skipped"
        if documents:
            log(f"CONFLICT {relative}: {len(documents)} document(s) with this Work Item, "
                f"content differs or more than one")
            return "conflict"

        attempts = self.state["attempts"].get(key, 0)
        if attempts >= self.max_attempts:
            log(f"FAILURE {relative}: not in Paperless after {attempts} attempt(s); review and acknowledge")
            return "failure"
        self.state["attempts"][key] = attempts + 1

        fields = [
            ("document", f"{external_id}.pdf"),
            ("title", external_id),
            ("document_type", self.type_id),
            ("custom_fields", json.dumps({str(self.field_id): work_item})),
            ("created", date.isoformat()),
        ]
        fields += [("tags", tag) for tag in self.tag_ids]
        try:
            self.api.upload(absolute, fields)
            outcome = self.confirm(work_item, digest)
        except ApiError as error:
            # Includes HTTP 5xx: only this file is affected; the run continues.
            log(f"ERROR {relative}: {error}")
            outcome = "timeout"
        if outcome == "uploaded":
            self.state["attempts"].pop(key, None)
            log(f"UPLOADED {relative}")
            return "uploaded"
        if outcome == "conflict":
            log(f"CONFLICT {relative}: another document with this Work Item appeared")
            return "conflict"
        if attempts + 1 >= self.max_attempts:
            log(f"FAILURE {relative}: not confirmed after {attempts + 1} attempt(s); review and acknowledge")
            return "failure"
        log(f"PENDING {relative}: not confirmed within {self.confirm_timeout}s; retried later")
        return "pending"

    def run(self):
        self.api.check_version()
        self.resolve_model()
        for absolute, relative in quote_files():
            try:
                info = os.stat(absolute)
                # A file still being written is left for the next run; ctime
                # ahead of the clock never defers, so it cannot loop.
                age = time.time() - info.st_ctime
                if 0 <= age < self.settle_seconds:
                    self.counts["deferred"] += 1
                    continue
                outcome = self.process(absolute, relative, sha256_of(absolute))
            except OSError as error:
                log(f"ERROR unreadable {relative}: {error.__class__.__name__}")
                outcome = "pending"
            self.counts[outcome] += 1
            if outcome in PENDING_RESULTS:
                self.pending_since.append(int(info.st_ctime))
        # Attempts of files that disappeared or changed content are dropped.
        self.state["attempts"] = {k: v for k, v in self.state["attempts"].items() if k in self.seen}
        if self.counts["deferred"]:
            forget_snapshot()
        summary = " ".join(f"{key}={value}" for key, value in self.counts.items())
        log(f"SUMMARY {summary}")

    def metrics(self, started, status):
        now = int(time.time())
        previous = self.state["metrics"]
        oldest = min(self.pending_since) if self.pending_since else 0
        return {
            "last_run_timestamp_seconds": now,
            "last_success_timestamp_seconds": now if status == 1 else previous.get("last_success_timestamp_seconds", 0),
            "last_status": status,
            "last_duration_seconds": now - int(started),
            "heartbeat_timestamp_seconds": now,
            "pending_files": len(self.pending_since),
            "oldest_pending_timestamp_seconds": oldest,
            "oldest_pending_age_seconds": now - oldest if oldest else 0,
            "files": dict(self.counts),
            "unresolved": {reason: self.counts[reason] for reason in UNRESOLVED_REASONS},
        }

    def wants_retry(self):
        return self.counts["pending"] > 0


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

    with lock:
        return _sync_locked(started)


def _sync_locked(started):
    remember_snapshot()
    token = os.environ.pop("PAPERLESS_QUOTE_TOKEN", "")
    state = load_state()
    try:
        if not token:
            raise SystemExit("PAPERLESS_QUOTE_TOKEN is required")
        api = Paperless(paperless_url(), token)
        sync = Sync(api, state, read_acknowledged(),
                    int_env("QUOTE_CONFIRM_TIMEOUT", 300), int_env("QUOTE_MAX_ATTEMPTS", 3),
                    int_env("QUOTE_SETTLE_SECONDS", 10))
        sync.run()
        state["metrics"] = sync.metrics(started, 1)
        save_state(state)
        publish_metrics(state["metrics"])
        return EXIT_RETRY if sync.wants_retry() else EXIT_OK
    except Unreachable as error:
        log(f"ERROR Paperless unreachable: {error}")
        _publish_failed(state, started)
        return EXIT_UNREACHABLE
    except (SystemExit, ApiError, ValueError) as error:
        # Any Paperless or configuration error, for example an invalid token or
        # an HTTP 500 while reading metadata: retried after QUOTE_RETRY_SECONDS,
        # never left until the daily run.
        log(f"ERROR {error}")
        _publish_failed(state, started)
        return EXIT_RETRY


def _publish_failed(state, started):
    """Publish a failed run without losing what the last completed run knew.

    Pending and unresolved files are only known from a completed run, so their
    values, and the oldest pending timestamp, are kept; publishing zero would
    silence the pending and review alerts exactly while Paperless is failing.
    """
    now = int(time.time())
    metrics = dict(state["metrics"])
    oldest = int(metrics.get("oldest_pending_timestamp_seconds", 0))
    metrics.update(last_run_timestamp_seconds=now, last_status=0,
                   last_duration_seconds=now - int(started), heartbeat_timestamp_seconds=now,
                   oldest_pending_age_seconds=now - oldest if oldest else 0)
    state["metrics"] = metrics
    save_state(state)
    publish_metrics(metrics)


# -----------------------------------------------------------------------------
# Other commands
# -----------------------------------------------------------------------------

def command_check_model():
    token = os.environ.pop("PAPERLESS_QUOTE_TOKEN", "")
    if not token:
        raise SystemExit("PAPERLESS_QUOTE_TOKEN is required")
    api = Paperless(paperless_url(), token)
    api.check_version()
    sync = Sync(api, load_state(), set(), 0, 1, 0)
    sync.resolve_model()
    log(f"Data model ready: type {sync.type_id}, tags {sync.tag_ids}, field {sync.field_id}")
    return EXIT_OK


def command_preview():
    """Show how each file validates and the metadata a sync would send. Nothing is uploaded."""
    acknowledged = read_acknowledged()
    for absolute, relative in quote_files():
        digest = sha256_of(absolute)
        if f"{relative} {digest}" in acknowledged:
            print(f"ACKNOWLEDGED {relative}")
            continue
        try:
            work_item, external_id, date = parse_name(relative)
            validate_pdf(absolute)
        except Rejected as reason:
            print(f"REJECTED {relative}: {reason}")
            continue
        print(f"VALID {relative} | {external_id} | {date.isoformat()} | {work_item} | sha256 {digest[:12]}")
    return EXIT_OK


def command_next_delay():
    hour = int_env("QUOTE_SYNC_HOUR", 3)
    now = dt.datetime.now()
    target = now.replace(hour=hour, minute=0, second=0, microsecond=0)
    if target <= now:
        target += dt.timedelta(days=1)
    print(int((target - now).total_seconds()))
    return EXIT_OK


def command_wait_ready():
    api = Paperless(paperless_url(), None)
    deadline = time.monotonic() + int_env("QUOTE_STARTUP_WAIT", 600)
    while time.monotonic() < deadline:
        try:
            api.get("/api/")
            return EXIT_OK
        except ApiError as error:
            if error.status and error.status < 500:
                return EXIT_OK
        except Unreachable:
            pass
        time.sleep(15)
    log("Paperless did not answer within QUOTE_STARTUP_WAIT; starting anyway.")
    return EXIT_OK


def command_wait_change(seconds):
    """Return after a stable folder change or when SECONDS elapse, whichever is first.

    The folder is polled every QUOTE_WATCH_INTERVAL seconds with a stat-only walk.
    A snapshot that differs from the last run's baseline must stay unchanged for
    QUOTE_SETTLE_SECONDS. The heartbeat is kept on every poll.
    """
    deadline = time.monotonic() + seconds
    interval = int_env("QUOTE_WATCH_INTERVAL", 30)
    settle = int_env("QUOTE_SETTLE_SECONDS", 10)
    if interval <= 0:
        time.sleep(max(0, seconds))
        return EXIT_OK
    pending, since = None, None
    while (remaining := deadline - time.monotonic()) > 0:
        time.sleep(min(interval, remaining))
        heartbeat()
        current = folder_snapshot()
        if current == read_snapshot():
            pending = None
        elif current != pending:
            pending, since = current, time.monotonic()
        elif time.monotonic() - since >= settle:
            log("Quotes folder changed and settled; starting sync.")
            return EXIT_OK
    return EXIT_OK


def main(arguments):
    commands = {
        "sync": command_sync,
        "preview": command_preview,
        "check-model": command_check_model,
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
