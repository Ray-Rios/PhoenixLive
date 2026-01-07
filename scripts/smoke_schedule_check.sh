#!/usr/bin/env bash
set -euo pipefail

# This runs a small script inside the cluster that creates a test project and triggers the scheduler compute
POD=$(kubectl get pods -n phoenixapp -l app=phoenix-web -o jsonpath='{.items[0].metadata.name}')

kubectl exec -n phoenixapp $POD -- /app/bin/phoenix_app eval '
{:ok, _} = Application.ensure_all_started(:phoenix_app)
alias PhoenixApp.Scheduler
alias PhoenixApp.Scheduler.Engine
start = DateTime.utc_now()
{:ok, project} = Scheduler.create_project(%{name: "engine-smoke-$(System.os_time())", start_date: start})
{:ok, a} = Scheduler.create_task(%{project_id: project.id, title: "A", duration_seconds: 3600})
{:ok, b} = Scheduler.create_task(%{project_id: project.id, title: "B", duration_seconds: 7200})
{:ok, _} = Scheduler.create_task_dependency(%{task_id: b.id, depends_on_task_id: a.id})
res = Engine.compute_schedule(project.id)
IO.inspect(res)
'
