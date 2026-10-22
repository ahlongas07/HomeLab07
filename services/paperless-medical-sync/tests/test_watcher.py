"""Tests for the change-triggered sync (Sprint 015 enhancement).

Standard library only and no Paperless instance; run from the repository root:

    python3 -m unittest discover -s services/paperless-medical-sync/tests

Timing uses one-second intervals, so the suite takes about 15 seconds.
"""

import fcntl
import os
import shutil
import sys
import tempfile
import threading
import time
import unicodedata
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import medical_sync as ms  # noqa: E402

TIMEOUT = 15


class FakeApi:
    def check_version(self):
        pass


class WatcherTest(unittest.TestCase):
    def setUp(self):
        self.base = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.base)
        self.patch("SOURCE_DIR", os.path.join(self.base, "source"))
        self.patch("WORK_DIR", os.path.join(self.base, "run"))
        self.patch("SNAPSHOT_FILE", os.path.join(ms.WORK_DIR, "snapshot"))
        self.patch("LOCK_FILE", os.path.join(ms.WORK_DIR, "sync.lock"))
        self.patch("log", lambda message: None)
        os.makedirs(os.path.join(ms.SOURCE_DIR, "2024", "Laboratorio"))
        os.makedirs(ms.WORK_DIR)
        for name, value in (("SYNC_WATCH_INTERVAL", "1"), ("SYNC_SETTLE_SECONDS", "1")):
            os.environ[name] = value
            self.addCleanup(os.environ.pop, name, None)
        self.processed = []

    def patch(self, name, value):
        original = getattr(ms, name)
        setattr(ms, name, value)
        self.addCleanup(setattr, ms, name, original)

    def write(self, relative, content=b"exam"):
        with open(os.path.join(ms.SOURCE_DIR, relative), "wb") as handle:
            handle.write(content)

    def run_sync(self, on_process=None):
        """Run Sync.run as command_sync does: baseline first, then the walk."""
        sync = ms.Sync(FakeApi(), ms.Namer({}, []), [], 1, 1)
        sync.resolve_model = lambda: None

        def process(absolute, relative, original_hash, ident):
            self.processed.append(relative)
            if on_process:
                on_process()

        sync.process = process
        ms.remember_snapshot()
        sync.run()
        return sync.counts

    def wait_change(self):
        """Seconds until wait-change returned; TIMEOUT means no change was seen."""
        started = time.monotonic()
        ms.command_wait_change(TIMEOUT)
        return time.monotonic() - started

    def test_unchanged_folder_waits_for_the_daily_run(self):
        self.write("2024/Laboratorio/a.pdf")
        time.sleep(1.1)
        self.run_sync()
        started = time.monotonic()
        ms.command_wait_change(3)
        self.assertGreaterEqual(time.monotonic() - started, 2.9)

    def test_deferred_file_is_retried_without_further_changes(self):
        # The copy finished just before the run: the file is deferred, and no
        # later change happens in the folder.
        self.write("2024/Laboratorio/a.pdf")
        counts = self.run_sync()
        self.assertEqual(counts["deferred"], 1)
        self.assertEqual(self.processed, [])
        self.assertIsNone(ms.read_snapshot())

        self.assertLess(self.wait_change(), TIMEOUT - 1)
        counts = self.run_sync()
        self.assertEqual(counts["deferred"], 0)
        self.assertEqual(self.processed, ["2024/Laboratorio/a.pdf"])

    def test_future_mtime_is_not_deferred_forever(self):
        # The copying client set a modification time one day ahead.
        self.write("2024/Laboratorio/a.pdf")
        future = time.time() + 86400
        os.utime(os.path.join(ms.SOURCE_DIR, "2024/Laboratorio/a.pdf"), (future, future))
        time.sleep(1.1)
        counts = self.run_sync()
        self.assertEqual(counts["deferred"], 0)
        self.assertEqual(self.processed, ["2024/Laboratorio/a.pdf"])
        self.assertIsNotNone(ms.read_snapshot())
        # No baseline drop, so the watcher does not start a run every interval.
        started = time.monotonic()
        ms.command_wait_change(3)
        self.assertGreaterEqual(time.monotonic() - started, 2.9)

    def test_file_copied_during_a_run_triggers_another_run(self):
        self.write("2024/Laboratorio/a.pdf")
        time.sleep(1.1)

        # Lands in a folder the walk has already listed, so this run misses it.
        def copy_during_run():
            self.write("late.pdf")

        self.run_sync(on_process=copy_during_run)
        self.assertEqual(self.processed, ["2024/Laboratorio/a.pdf"])
        self.assertLess(self.wait_change(), TIMEOUT - 1)

        time.sleep(1.1)
        self.processed.clear()
        self.run_sync()
        self.assertIn("late.pdf", self.processed)

    def test_locked_run_does_not_absorb_the_change(self):
        self.write("2024/Laboratorio/a.pdf")
        time.sleep(1.1)
        self.run_sync()
        baseline = ms.read_snapshot()

        self.write("2024/Laboratorio/b.pdf")
        with open(ms.LOCK_FILE, "w") as holder:
            fcntl.flock(holder, fcntl.LOCK_EX | fcntl.LOCK_NB)
            self.assertEqual(ms.command_sync(), ms.EXIT_LOCKED)
        self.assertEqual(ms.read_snapshot(), baseline)
        self.assertLess(self.wait_change(), TIMEOUT - 1)

    def test_batch_copy_settles_once(self):
        self.write("2024/Laboratorio/a.pdf")
        time.sleep(1.1)
        self.run_sync()
        # Simulate a slow copy of several files: wait-change must not return
        # while the folder keeps changing.
        def slow_copy():
            for index in range(4):
                self.write(f"2024/Laboratorio/batch-{index}.pdf")
                time.sleep(0.7)

        copier = threading.Thread(target=slow_copy)
        started = time.monotonic()
        copier.start()
        ms.command_wait_change(TIMEOUT)
        elapsed = time.monotonic() - started
        copier.join()
        self.assertGreaterEqual(elapsed, 2.8)
        self.assertLess(elapsed, TIMEOUT - 1)


class TagNormalizationTest(unittest.TestCase):
    def test_nfd_tag_is_found_from_nfc_map(self):
        stored = unicodedata.normalize("NFD", "Ecografía")

        class Api(ms.Paperless):
            def get(self, path, **query):
                if "name__iexact" in query:
                    return {"results": []}  # Server-side compare misses NFD.
                if query["page"] == 1:
                    return {"results": [{"id": 1, "name": "Laboratorio"}], "next": "page-2"}
                return {"results": [{"id": 7, "name": stored}], "next": None}

        api = Api("http://paperless.invalid", None)
        self.assertEqual(api.find_by_name("/api/tags/", "Ecografía")["id"], 7)
        self.assertIsNone(api.find_by_name("/api/tags/", "Audiometría"))
        self.assertEqual(ms.Namer({"eco": stored}, []).categories["eco"], "Ecografía")


if __name__ == "__main__":
    unittest.main()
