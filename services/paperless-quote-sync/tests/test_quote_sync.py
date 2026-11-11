"""Tests for the quote archive sync (Sprint 020).

Standard library only, no Paperless instance and no qpdf; run from the
repository root:

    python3 -m unittest discover -s services/paperless-quote-sync/tests
"""

import json
import os
import shutil
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import quote_sync as qs  # noqa: E402

ME = 7
UUID = "0b1c2d3e-4f50-4a6b-8c7d-9e0f1a2b3c4d"
NAME = f"{UUID}__RFQ-123-R1__2026-11-10.pdf"
PDF = b"%PDF-1.4\n%quote\n"


class FakePaperless(qs.Paperless):
    """In-memory Paperless: contract objects, documents by Work Item, uploads recorded.

    `confirm_uploads` controls whether an upload appears in the search (as
    Paperless does after consuming the file) or never does (a discarded
    duplicate, which the sync sees only as a confirmation timeout).
    """

    def __init__(self):
        super().__init__("http://paperless.invalid", "token")
        self.last_api_version = "10"
        self.documents = []  # (id, work_item, checksum)
        self.uploads = []
        self.confirm_uploads = True
        self.next_id = 100
        self.objects = {
            "/api/document_types/": [{"id": 1, "name": qs.DOCUMENT_TYPE, "owner": ME}],
            "/api/tags/": [{"id": 2, "name": qs.TAG_JUANCHOAI, "owner": ME},
                           {"id": 3, "name": qs.TAG_FINAL, "owner": ME},
                           {"id": 4, "name": qs.TAG_FINAL, "owner": 99}],
            "/api/custom_fields/": [{"id": 5, "name": qs.FIELD_WORK_ITEM}],
        }

    def add_document(self, work_item, checksum):
        self.next_id += 1
        self.documents.append((self.next_id, work_item, checksum))

    def get(self, path, **query):
        if path == "/api/ui_settings/":
            return {"user": {"id": ME}}
        if path in self.objects:
            items = self.objects[path]
            if "name__iexact" in query:
                items = [i for i in items if i["name"].casefold() == query["name__iexact"].casefold()]
            return {"results": items, "next": None}
        if path == "/api/documents/":
            field, operator, value = json.loads(query["custom_field_query"])
            assert (field, operator) == (5, "exact")
            return {"results": [
                {"id": i, "custom_fields": [{"field": 5, "value": w}]}
                for i, w, _ in self.documents if w == value
            ], "next": None}
        if path.startswith("/api/documents/") and path.endswith("/metadata/"):
            wanted = int(path.split("/")[3])
            return {"original_checksum": next(c for i, _, c in self.documents if i == wanted)}
        raise AssertionError(path)

    def upload(self, file_path, fields):
        self.uploads.append(dict(fields))
        if self.confirm_uploads:
            work_item = json.loads(dict(fields)["custom_fields"])["5"]
            self.add_document(work_item, qs.sha256_of(file_path))
        return "task"


class NameTest(unittest.TestCase):
    def test_valid_name(self):
        self.assertEqual(qs.parse_name(f"2026/{NAME}"),
                         (UUID, "RFQ-123-R1", qs.dt.date(2026, 11, 10)))

    def test_rejected_names(self):
        for relative in (
            f"{NAME}",                                              # no year folder
            f"2026/sub/{NAME}",                                     # too deep
            f"2025/{NAME}",                                         # year mismatch
            f"2026/{UUID.upper()}__RFQ-1__2026-11-10.pdf",           # uppercase uuid
            f"2026/{UUID}__RFQ__1__2026-11-10.pdf",                  # "__" inside external_id
            f"2026/{UUID}__RFQ 1__2026-11-10.pdf",                   # space
            f"2026/{UUID}__RFQ-Ñ__2026-11-10.pdf",                   # accented character
            f"2026/{UUID}__{'a' * 65}__2026-11-10.pdf",              # too long
            f"2026/{UUID}__RFQ-1__2026-02-30.pdf",                   # invalid date
            f"2026/{UUID}__RFQ-1__2026-11-10.PDF",                   # wrong extension case
            f"abcd/{UUID}__RFQ-1__2026-11-10.pdf",                   # folder not a year
        ):
            with self.subTest(relative=relative):
                with self.assertRaises(qs.Rejected):
                    qs.parse_name(relative)


class SyncTest(unittest.TestCase):
    def setUp(self):
        self.base = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.base)
        self.patch("QUOTES_DIR", os.path.join(self.base, "quotes"))
        self.patch("WORK_DIR", os.path.join(self.base, "run"))
        self.patch("METRICS_DIR", os.path.join(self.base, "metrics"))
        self.patch("ACK_FILE", os.path.join(self.base, "ack"))
        self.patch("STATE_FILE", os.path.join(qs.WORK_DIR, "state.json"))
        self.patch("SNAPSHOT_FILE", os.path.join(qs.WORK_DIR, "snapshot"))
        self.patch("pdf_encrypted", lambda path: False)
        self.patch("log", lambda message: None)
        for directory in (os.path.join(qs.QUOTES_DIR, "2026"), qs.WORK_DIR, qs.METRICS_DIR):
            os.makedirs(directory)
        self.api = FakePaperless()
        self.state = {"attempts": {}, "metrics": {}}

    def patch(self, name, value):
        original = getattr(qs, name)
        setattr(qs, name, value)
        self.addCleanup(setattr, qs, name, original)

    def write(self, relative, content=PDF):
        path = os.path.join(qs.QUOTES_DIR, relative)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "wb") as handle:
            handle.write(content)
        return path

    def sync(self, max_attempts=3, acknowledged=None):
        sync = qs.Sync(self.api, self.state, acknowledged or set(), 0, max_attempts, 0)
        sync.run()
        return sync

    def test_valid_file_is_uploaded_with_contract_metadata(self):
        self.write(f"2026/{NAME}")
        sync = self.sync()
        self.assertEqual(sync.counts["uploaded"], 1)
        upload = self.api.uploads[0]
        self.assertEqual(upload["document"], "RFQ-123-R1.pdf")
        self.assertEqual(upload["title"], "RFQ-123-R1")
        self.assertEqual(upload["document_type"], 1)
        self.assertEqual(upload["created"], "2026-11-10")
        self.assertEqual(json.loads(upload["custom_fields"]), {"5": UUID})
        self.assertEqual(sync.pending_since, [])
        self.assertEqual(self.state["attempts"], {})

    def test_existing_document_with_same_content_is_skipped(self):
        path = self.write(f"2026/{NAME}")
        self.api.add_document(UUID, qs.sha256_of(path))
        sync = self.sync()
        self.assertEqual(sync.counts["skipped"], 1)
        self.assertEqual(self.api.uploads, [])

    def test_different_content_is_a_conflict(self):
        self.write(f"2026/{NAME}")
        self.api.add_document(UUID, "0" * 64)
        sync = self.sync()
        self.assertEqual(sync.counts["conflict"], 1)
        self.assertEqual(self.api.uploads, [])
        self.assertEqual(sync.metrics(0, 1)["unresolved"], {"rejected": 0, "conflict": 1, "failure": 0})

    def test_more_than_one_document_is_a_conflict_even_with_same_content(self):
        path = self.write(f"2026/{NAME}")
        digest = qs.sha256_of(path)
        self.api.add_document(UUID, digest)
        self.api.add_document(UUID, digest)
        sync = self.sync()
        self.assertEqual(sync.counts["conflict"], 1)
        self.assertEqual(self.api.uploads, [])

    def test_invalid_files_are_rejected_and_never_uploaded(self):
        self.write(f"2026/{UUID}__RFQ 1__2026-11-10.pdf")
        self.write(f"2026/{UUID.replace('0b1c', '1b1c')}__RFQ-2__2026-11-10.pdf", b"not a pdf")
        self.write(f"2026/{UUID.replace('0b1c', '2b1c')}__RFQ-3__2026-11-10.pdf", PDF + b"x" * (qs.MAX_SIZE + 1))
        self.patch("pdf_encrypted", lambda path: True)
        self.write(f"2026/{UUID.replace('0b1c', '3b1c')}__RFQ-4__2026-11-10.pdf")
        sync = self.sync()
        self.assertEqual(sync.counts["rejected"], 4)
        self.assertEqual(self.api.uploads, [])
        self.assertEqual(sync.metrics(0, 1)["unresolved"]["rejected"], 4)
        self.assertEqual(sync.pending_since, [])

    def test_temporary_and_foreign_files_are_ignored(self):
        self.write(f"2026/.{NAME}.tmp")
        self.write("2026/notes.txt")
        sync = self.sync()
        self.assertEqual(sum(sync.counts.values()), 0)

    def test_unconfirmed_upload_is_pending_then_failure_after_max_attempts(self):
        self.write(f"2026/{NAME}")
        self.api.confirm_uploads = False
        first = self.sync(max_attempts=2)
        self.assertEqual(first.counts["pending"], 1)
        self.assertTrue(first.wants_retry())
        self.assertEqual(len(first.pending_since), 1)
        second = self.sync(max_attempts=2)
        self.assertEqual(second.counts["failure"], 1)
        self.assertFalse(second.wants_retry())
        self.assertEqual(len(self.api.uploads), 2)
        # No further upload: the file stays failure until acknowledged.
        third = self.sync(max_attempts=2)
        self.assertEqual(third.counts["failure"], 1)
        self.assertEqual(len(self.api.uploads), 2)
        metrics = third.metrics(0, 1)
        self.assertEqual(metrics["unresolved"]["failure"], 1)
        self.assertEqual(metrics["pending_files"], 1)
        self.assertGreater(metrics["oldest_pending_timestamp_seconds"], 0)

    def test_late_confirmation_clears_attempts(self):
        path = self.write(f"2026/{NAME}")
        self.api.confirm_uploads = False
        self.sync()
        self.assertEqual(self.state["attempts"], {f"2026/{NAME} {qs.sha256_of(path)}": 1})
        self.api.add_document(UUID, qs.sha256_of(path))
        sync = self.sync()
        self.assertEqual(sync.counts["skipped"], 1)
        self.assertEqual(self.state["attempts"], {})

    def test_changed_content_is_a_new_file_for_the_attempt_counter(self):
        self.write(f"2026/{NAME}")
        self.api.confirm_uploads = False
        self.sync(max_attempts=1)
        self.assertEqual(self.sync(max_attempts=1).counts["failure"], 1)
        self.write(f"2026/{NAME}", PDF + b"revised")
        sync = self.sync(max_attempts=1)
        # Uploaded again (new SHA-256), unconfirmed, so failure on the first attempt.
        self.assertEqual(sync.counts["failure"], 1)
        self.assertEqual(len(self.api.uploads), 2)
        self.assertEqual(len(self.state["attempts"]), 1)

    def test_acknowledged_file_counts_neither_unresolved_nor_pending(self):
        path = self.write(f"2026/{NAME}")
        self.api.confirm_uploads = False
        self.sync(max_attempts=1)
        digest = qs.sha256_of(path)
        with open(qs.ACK_FILE, "w", encoding="utf-8") as handle:
            handle.write(f"# reviewed\n2026/{NAME} {digest}\nbad line\n")
        acknowledged = qs.read_acknowledged()
        self.assertEqual(acknowledged, {f"2026/{NAME} {digest}"})
        sync = self.sync(max_attempts=1, acknowledged=acknowledged)
        self.assertEqual(sync.counts["acknowledged"], 1)
        self.assertEqual(len(self.api.uploads), 1)
        metrics = sync.metrics(0, 1)
        self.assertEqual(metrics["unresolved"], {"rejected": 0, "conflict": 0, "failure": 0})
        self.assertEqual(metrics["pending_files"], 0)
        self.assertEqual(metrics["oldest_pending_timestamp_seconds"], 0)
        # A changed file no longer matches the acknowledged SHA-256 and counts again.
        self.write(f"2026/{NAME}", PDF + b"revised")
        sync = self.sync(max_attempts=1, acknowledged=acknowledged)
        self.assertEqual(sync.counts["acknowledged"], 0)
        self.assertEqual(len(self.api.uploads), 2)
        self.assertEqual(sync.metrics(0, 1)["unresolved"]["failure"], 1)

    def test_model_objects_must_belong_to_the_sync_user(self):
        self.api.objects["/api/tags/"] = [{"id": 2, "name": qs.TAG_JUANCHOAI, "owner": ME},
                                          {"id": 4, "name": qs.TAG_FINAL, "owner": 99}]
        with self.assertRaises(SystemExit):
            self.sync()
        self.assertEqual(self.api.uploads, [])

    def test_metrics_file_lists_every_result_and_reason(self):
        self.write(f"2026/{NAME}")
        sync = self.sync()
        qs.publish_metrics(sync.metrics(0, 1))
        with open(os.path.join(qs.METRICS_DIR, qs.METRICS_FILE), encoding="utf-8") as handle:
            text = handle.read()
        for result in qs.RESULTS:
            self.assertIn(f'_files{{result="{result}"}} ', text)
        for reason in qs.UNRESOLVED_REASONS:
            self.assertIn(f'_unresolved{{reason="{reason}"}} 0', text)
        self.assertIn("_files{result=\"uploaded\"} 1", text)
        self.assertIn("_last_status 1", text)
        self.assertIn("_heartbeat_timestamp_seconds ", text)

    def test_heartbeat_refresh_keeps_other_metrics(self):
        self.write(f"2026/{NAME}")
        sync = self.sync()
        self.state["metrics"] = sync.metrics(0, 1)
        qs.save_state(self.state)
        qs.refresh_heartbeat()
        with open(os.path.join(qs.METRICS_DIR, qs.METRICS_FILE), encoding="utf-8") as handle:
            text = handle.read()
        self.assertIn("_files{result=\"uploaded\"} 1", text)


if __name__ == "__main__":
    unittest.main()
