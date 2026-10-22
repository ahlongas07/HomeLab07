"""Tests for model-init read-only users (Sprint 015 enhancement).

Standard library only; Paperless is replaced by an in-memory fake. Run from the
repository root:

    python3 -m unittest discover -s services/paperless-medical-sync/tests
"""

import io
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import medical_sync as ms  # noqa: E402

OWNER = "owner"
READER = "agente-medico"


class FakePaperless(ms.Paperless):
    """In-memory Paperless API: collections keyed by path, writes recorded."""

    state = None

    def __init__(self, base_url, token):
        super().__init__(base_url, token)
        self.last_api_version = "10"

    @classmethod
    def reset(cls, users=(OWNER, READER)):
        cls.state = {
            "users": [{"id": i + 1, "username": name} for i, name in enumerate(users)],
            "document_types": [],
            "tags": [{"id": 900, "name": "Manual tag"}],
            "correspondents": [{"id": 700, "name": "Clinic"}],
            "custom_fields": [],
            "workflows": [],
            "documents": [],
            "writes": [],
            "next_id": 100,
        }

    def request(self, method, path, query=None, body=None, headers=None, timeout=60):
        state = type(self).state
        parts = [p for p in path.split("/") if p]
        collection = parts[1] if len(parts) > 1 else ""
        if method == "GET":
            items = state.get(collection, [])
            query = query or {}
            for key, value in query.items():
                if key.endswith("__iexact"):
                    field = key[: -len("__iexact")]
                    items = [i for i in items if str(i.get(field, "")).casefold() == str(value).casefold()]
                if key == "tags__id__all":
                    items = [i for i in items if int(value) in i.get("tags", [])]
            return {"results": items, "next": None}
        state["writes"].append((method, path, body))
        if method == "POST" and path in ("/api/bulk_edit_objects/", "/api/documents/bulk_edit/"):
            return {"result": "OK"}
        if method == "POST":
            item = dict(body)
            item["id"] = state["next_id"]
            state["next_id"] += 1
            state[collection].append(item)
            return item
        return {}


class ModelInitTest(unittest.TestCase):
    def setUp(self):
        FakePaperless.reset()
        self.addCleanup(setattr, ms, "Paperless", ms.Paperless)
        ms.Paperless = FakePaperless
        self.addCleanup(setattr, ms, "log", ms.log)
        ms.log = lambda message: None
        self.env = {
            "SYNC_OWNER_USERNAME": OWNER,
            "SYNC_CATEGORY_MAP": '{"laboratorio": "Laboratorio"}',
            "SYNC_READER_USERNAMES": "",
        }
        for name in self.env:
            self.addCleanup(os.environ.pop, name, None)

    def run_model_init(self, readers=None):
        if readers is not None:
            self.env["SYNC_READER_USERNAMES"] = readers
        os.environ.update(self.env)
        original_stdin = sys.stdin
        sys.stdin = io.StringIO("admin-token\n")
        try:
            return ms.command_model_init()
        finally:
            sys.stdin = original_stdin

    @property
    def writes(self):
        return FakePaperless.state["writes"]

    def sync_id(self):
        return next(u["id"] for u in FakePaperless.state["users"] if u["username"] == ms.SYNC_USERNAME)

    def view_users_of_contract_objects(self):
        return [w[2]["set_permissions"]["view"]["users"] for w in self.writes
                if w[0] in ("POST", "PATCH") and w[2] and "set_permissions" in w[2]]

    def workflow(self):
        return FakePaperless.state["workflows"][0]

    def test_without_readers_behaves_as_before(self):
        self.assertEqual(self.run_model_init("[]"), ms.EXIT_OK)
        sync_id = self.sync_id()
        self.assertTrue(all(users == [sync_id] for users in self.view_users_of_contract_objects()))
        self.assertEqual(self.workflow()["actions"][0]["assign_view_users"], [sync_id])
        paths = [w[1] for w in self.writes]
        self.assertNotIn("/api/bulk_edit_objects/", paths)
        self.assertNotIn("/api/documents/bulk_edit/", paths)
        self.assertFalse(any(p == "/api/users/2/" for p in paths))

    def test_reader_gets_view_only_access_everywhere(self):
        medical_docs = [{"id": 1, "tags": []}, {"id": 2, "tags": []}, {"id": 3, "tags": [555]}]
        FakePaperless.state["documents"] = medical_docs
        self.run_model_init(f'["{READER}"]')
        reader_id, sync_id = 2, self.sync_id()

        reader_patch = next(w[2] for w in self.writes if w[0] == "PATCH" and w[1] == f"/api/users/{reader_id}/")
        self.assertEqual(reader_patch, {"is_staff": False, "is_superuser": False, "groups": [],
                                        "user_permissions": ms.READER_PERMISSIONS})
        self.assertFalse(any(p.startswith(("add_", "change_", "delete_")) for p in ms.READER_PERMISSIONS))

        for users in self.view_users_of_contract_objects():
            self.assertEqual(users, [sync_id, reader_id])
        self.assertEqual(self.workflow()["actions"][0]["assign_view_users"], [sync_id, reader_id])

        medical_tag = next(t["id"] for t in FakePaperless.state["tags"] if t["name"] == ms.TAG_MEDICAL)
        for doc in medical_docs[:2]:
            doc["tags"] = [medical_tag]
        FakePaperless.state["writes"].clear()
        self.run_model_init()

        bulk_objects = {w[2]["object_type"]: w[2] for w in self.writes if w[1] == "/api/bulk_edit_objects/"}
        all_tags = sorted(t["id"] for t in FakePaperless.state["tags"])
        self.assertEqual(sorted(bulk_objects["tags"]["objects"]), all_tags)
        self.assertEqual(bulk_objects["correspondents"]["objects"], [700])
        for body in bulk_objects.values():
            self.assertTrue(body["merge"])
            self.assertNotIn("owner", body)
            self.assertEqual(body["permissions"]["view"]["users"], [reader_id])
        documents = next(w[2] for w in self.writes if w[1] == "/api/documents/bulk_edit/")
        self.assertEqual(documents["documents"], [1, 2])
        self.assertTrue(documents["parameters"]["merge"])
        self.assertNotIn("owner", documents["parameters"])

    def test_second_run_is_idempotent(self):
        self.run_model_init(f'["{READER}"]')
        workflows = len(FakePaperless.state["workflows"])
        objects = {key: len(FakePaperless.state[key]) for key in ("tags", "document_types", "custom_fields", "users")}
        self.assertEqual(self.run_model_init(), ms.EXIT_OK)
        self.assertEqual(len(FakePaperless.state["workflows"]), workflows)
        self.assertEqual({key: len(FakePaperless.state[key]) for key in objects}, objects)

    def test_missing_reader_stops_without_changes(self):
        FakePaperless.reset(users=(OWNER,))
        with self.assertRaises(SystemExit) as raised:
            self.run_model_init(f'["{READER}"]')
        self.assertIn("does not exist", str(raised.exception))
        self.assertEqual(self.writes, [])

    def test_owner_or_sync_user_cannot_be_reader(self):
        for name in (OWNER, ms.SYNC_USERNAME):
            FakePaperless.reset()
            with self.assertRaises(SystemExit):
                self.run_model_init(f'["{name}"]')
            self.assertEqual(self.writes, [])

    def test_invalid_reader_list_stops(self):
        for value in ('"agente-medico"', '[""]', "[1]"):
            with self.assertRaises(SystemExit):
                self.run_model_init(value)

    def test_workflow_without_reader_is_drift(self):
        self.run_model_init("[]")
        with self.assertRaises(SystemExit) as raised:
            self.run_model_init(f'["{READER}"]')
        self.assertIn("differs from the Sprint 015 contract", str(raised.exception))


if __name__ == "__main__":
    unittest.main()
