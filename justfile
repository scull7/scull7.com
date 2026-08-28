# Pinto is the only project-management source of truth.
# `just status` renders `pinto list --json`. Never hand-edit `.pinto/tasks/*.md`.

status:
    python3 scripts/status-dashboard

status-html:
    python3 scripts/status-dashboard --html
