## The Boots home (the one thing you must not get wrong)

Boots keeps every record in a folder on the user's **own computer**, never in the
session. This session is wiped when it ends; a record written here is gone by the
next chat, which is the exact failure this suite exists to prevent.

If Step A returned `BOOTS_MODE absent`, read
`{{SKILL_DIR}}/reference/boots-home.md` and follow "First run".

The short version, and the part people get wrong: **`absent` is a question, not an
answer.** Before you create anything, check the two places the probe cannot see —
the connected folders, over the bridge, and the names-only listing of the user's
home folder that `get_device_info` returns without needing permission. A `.boots`
or a `Boots` in that listing means the user already has a home and you simply have
not been given access to it; ask for it with `device_request_folder_access`.

Only when all of those come up empty is there really no home. Then: if there is a
connected folder, create the home there and mention in one line where it went. If
there is no connected folder at all, say so **before** doing any work — Boots
cannot record anything, and losing twenty minutes of work is worse than a sentence
up front.
