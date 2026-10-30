"""Tests for model-init read-only users (Sprint 015 enhancement, Sprint 019 isolation).

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
OWNER_ID, READER_ID, OTHER_ID = 1, 2, 50


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
            "tags": [{"id": 900, "name": "Manual tag", "owner": OWNER_ID}],
            "correspondents": [{"id": 700, "name": "Clinic", "owner": OWNER_ID}],
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
            if query.get("full_perms") != "true":
                items = [{k: v for k, v in i.items() if k != "permissions"} for i in items]
            return {"results": items, "next": None}
        state["writes"].append((method, path, body))
        if method == "POST" and path in ("/api/bulk_edit_objects/", "/api/documents/bulk_edit/"):
            return {"result": "OK"}
        if method == "POST":
            item = dict(body)
            item["id"] = state["next_id"]
            state["next_id"] += 1
            if "set_permissions" in item:
                item["permissions"] = item.pop("set_permissions")
            state[collection].append(item)
            return item
        if method == "PATCH" and len(parts) > 2 and collection in state:
            for item in state[collection]:
                if str(item["id"]) == parts[2]:
                    changes = dict(body)
                    if "set_permissions" in changes:
                        item["permissions"] = changes.pop("set_permissions")
                    item.update(changes)
        return {}


class ModelInitTest(unittest.TestCase):
    def setUp(self):
        FakePaperless.reset()
        self.addCleanup(setattr, ms, "Paperless", ms.Paperless)
        ms.Paperless = FakePaperless
        self.addCleanup(setattr, ms, "log", ms.log)
        self.messages = []
        ms.log = self.messages.append
        self.env = {
            "SYNC_OWNER_USERNAME": OWNER,
            "SYNC_CATEGORY_MAP": '{"laboratorio": "Laboratorio"}',
            "SYNC_READER_USERNAMES": "",
        }
        for name in self.env:
            self.addCleanup(os.environ.pop, name, None)

    def run_command(self, command, readers=None):
        if readers is not None:
            self.env["SYNC_READER_USERNAMES"] = readers
        os.environ.update(self.env)
        original_stdin = sys.stdin
        sys.stdin = io.StringIO("admin-token\n")
        try:
            return command()
        finally:
            sys.stdin = original_stdin

    def run_model_init(self, readers=None):
        return self.run_command(ms.command_model_init, readers)

    def bulk_objects(self):
        return {w[2]["object_type"]: w[2] for w in self.writes if w[1] == "/api/bulk_edit_objects/"}

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
        medical_docs = [{"id": i, "tags": tags, "owner": OWNER_ID}
                        for i, tags in ((1, []), (2, []), (3, [555]))]
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

        bulk_objects = self.bulk_objects()
        managed_tags = sorted(t["id"] for t in FakePaperless.state["tags"] if t["id"] != 900)
        self.assertEqual(sorted(bulk_objects["tags"]["objects"]), managed_tags)
        self.assertEqual(bulk_objects["correspondents"]["objects"], [700])
        for body in bulk_objects.values():
            self.assertTrue(body["merge"])
            self.assertNotIn("owner", body)
            self.assertEqual(body["permissions"]["view"]["users"], [reader_id])
        documents = next(w[2] for w in self.writes if w[1] == "/api/documents/bulk_edit/")
        self.assertEqual(documents["documents"], [1, 2])
        self.assertTrue(documents["parameters"]["merge"])
        self.assertNotIn("owner", documents["parameters"])

    def test_objects_of_other_owners_are_never_shared(self):
        """ISO-01: tags and correspondents of another owner, or without owner."""
        state = FakePaperless.state
        state["tags"] += [{"id": 901, "name": "juanchoai", "owner": OTHER_ID},
                          {"id": 902, "name": ms.TAG_MEDICAL, "owner": OTHER_ID},
                          {"id": 903, "name": "Unowned", "owner": None}]
        state["correspondents"] += [{"id": 701, "name": "Carrier", "owner": OTHER_ID},
                                    {"id": 702, "name": "Unowned", "owner": None}]
        self.run_model_init(f'["{READER}"]')
        medical_tag = next(t["id"] for t in state["tags"] if t["name"] == ms.TAG_MEDICAL and t["owner"] == OWNER_ID)
        state["documents"] = [{"id": 1, "tags": [medical_tag], "owner": OWNER_ID},
                              {"id": 2, "tags": [medical_tag], "owner": OTHER_ID}]
        state["writes"].clear()
        self.run_model_init()

        bulk_objects = self.bulk_objects()
        self.assertTrue({900, 901, 902, 903}.isdisjoint(bulk_objects["tags"]["objects"]))
        self.assertEqual(bulk_objects["correspondents"]["objects"], [700])
        documents = next(w[2] for w in self.writes if w[1] == "/api/documents/bulk_edit/")
        self.assertEqual(documents["documents"], [1])
        foreign = ("/api/tags/901/", "/api/tags/902/", "/api/tags/903/",
                   "/api/correspondents/701/", "/api/correspondents/702/")
        self.assertFalse(any(w[1] in foreign for w in self.writes))
        # A same-named tag of another owner is left alone; model-init creates its own.
        self.assertEqual(next(t for t in state["tags"] if t["id"] == 902)["owner"], OTHER_ID)
        self.assertEqual(sum(t["name"] == ms.TAG_MEDICAL for t in state["tags"]), 2)

    def test_unowned_managed_tag_is_adopted(self):
        FakePaperless.state["tags"].append({"id": 904, "name": ms.TAG_MEDICAL, "owner": None})
        self.run_model_init("[]")
        patch = next(w[2] for w in self.writes if w[0] == "PATCH" and w[1] == "/api/tags/904/")
        self.assertEqual(patch["owner"], OWNER_ID)
        self.assertEqual(sum(t["name"] == ms.TAG_MEDICAL for t in FakePaperless.state["tags"]), 1)

    def test_reader_cleanup_removes_only_readers_outside_scope(self):
        self.run_model_init(f'["{READER}"]')
        state = FakePaperless.state
        both = {"view": {"users": [READER_ID, 7], "groups": [3]}, "change": {"users": [7], "groups": []}}
        state["tags"] += [{"id": 901, "name": "juanchoai", "owner": OTHER_ID, "permissions": both}]
        state["correspondents"] += [{"id": 701, "name": "Carrier", "owner": OTHER_ID, "permissions": both}]
        state["correspondents"][0]["permissions"] = {"view": {"users": [READER_ID], "groups": []}}
        state["writes"].clear()

        self.assertEqual(self.run_command(ms.command_reader_cleanup), ms.EXIT_OK)
        patched = sorted(w[1] for w in self.writes)
        self.assertEqual(patched, ["/api/correspondents/701/", "/api/tags/901/"])
        expected = {"view": {"users": [7], "groups": [3]}, "change": {"users": [7], "groups": []}}
        self.assertEqual(state["tags"][-1]["permissions"], expected)
        self.assertEqual(state["correspondents"][-1]["permissions"], expected)
        self.assertEqual(state["correspondents"][0]["permissions"]["view"]["users"], [READER_ID])
        self.assertIn("Cleanup complete: 2 objects changed.", self.messages[-1])

        state["writes"].clear()
        self.run_command(ms.command_reader_cleanup)
        self.assertEqual(self.writes, [])
        self.assertIn("Cleanup complete: 0 objects changed.", self.messages[-1])

    def test_reader_cleanup_requires_readers(self):
        with self.assertRaises(SystemExit):
            self.run_command(ms.command_reader_cleanup, "[]")
        self.assertEqual(self.writes, [])

    def test_unowned_objects_end_with_warning(self):
        FakePaperless.state["tags"].append({"id": 903, "name": "Unowned", "owner": None})
        FakePaperless.state["documents"] = [{"id": 5, "tags": [], "owner": None}]
        self.assertEqual(self.run_model_init("[]"), ms.EXIT_OK)
        self.assertIn("WARNING 1 without owner in /api/documents/: ids 5", self.messages)
        self.assertIn("WARNING 1 without owner in /api/tags/: ids 903", self.messages)
        self.assertTrue(self.messages[-1].startswith("Data model ready with warnings"))

    def test_without_unowned_objects_no_warning(self):
        self.run_model_init("[]")
        self.assertFalse(any(m.startswith("WARNING") for m in self.messages))
        self.assertTrue(self.messages[-1].startswith("Data model ready. "))

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
