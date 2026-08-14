import { NextResponse, type NextRequest } from "next/server";
import { execFile } from "child_process";
import { promisify } from "util";

const execFileAsync = promisify(execFile);

const SCRIPT = "/DATA/.hermes/scripts/agent-cron-manager.py";

interface CronJobAPI {
  id: string;
  name: string;
  agent_id: string;
  schedule: string;
  prompt_preview: string;
  prompt_full: string;
  enabled: boolean;
  state: string;
  last_run_at: string | null;
  last_status: string | null;
  last_error: string | null;
  next_run_at: string | null;
  repeat_completed: number;
  created_at: string;
  paused_at: string | null;
  deliver: string;
  skills: string[];
  no_agent: boolean;
}

// ═══════════════════════════════════════════════════════════════
// GET /api/admin/cron-jobs — List all agent cron jobs
//   Query: ?agent=ceo → filter by agent
// ═══════════════════════════════════════════════════════════════
export async function GET(request: NextRequest) {
  try {
    const { searchParams } = request.nextUrl;
    const agent = searchParams.get("agent") || undefined;

    const args = ["list"];
    if (agent) args.push(agent);

    const { stdout } = await execFileAsync("python3", [SCRIPT, ...args], {
      timeout: 10_000,
      maxBuffer: 1024 * 1024,
    });

    const data = JSON.parse(stdout);
    return NextResponse.json(data);
  } catch (err: any) {
    console.error("[cron-jobs:GET]", err.message);
    return NextResponse.json(
      { success: false, error: err.message },
      { status: 500 }
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// POST /api/admin/cron-jobs — Manage cron jobs
//   Body: {
//     action: "pause" | "resume" | "remove" | "edit" | "create" | "run",
//     job_id?: string,
//     agent_id?: string,
//     name?: string,
//     schedule?: string,
//     prompt?: string,
//   }
// ═══════════════════════════════════════════════════════════════
export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const { action, job_id, agent_id, name, schedule, prompt } = body;

    if (!action) {
      return NextResponse.json(
        { success: false, error: "action is required" },
        { status: 400 }
      );
    }

    switch (action) {
      case "pause":
      case "resume":
      case "remove":
      case "run": {
        if (!job_id) {
          return NextResponse.json(
            { success: false, error: "job_id is required" },
            { status: 400 }
          );
        }
        const { stdout } = await execFileAsync(
          "python3",
          [SCRIPT, action, job_id],
          { timeout: 15_000, maxBuffer: 1024 * 1024 }
        );
        return NextResponse.json(JSON.parse(stdout));
      }

      case "edit": {
        if (!job_id) {
          return NextResponse.json(
            { success: false, error: "job_id is required" },
            { status: 400 }
          );
        }
        const editArgs = [SCRIPT, "edit", job_id];
        if (name) editArgs.push("--name", name);
        if (schedule) editArgs.push("--schedule", schedule);
        if (prompt) editArgs.push("--prompt", prompt);

        const { stdout } = await execFileAsync("python3", editArgs, {
          timeout: 15_000,
          maxBuffer: 1024 * 1024,
        });
        return NextResponse.json(JSON.parse(stdout));
      }

      case "create": {
        if (!agent_id || !name || !schedule || !prompt) {
          return NextResponse.json(
            {
              success: false,
              error: "agent_id, name, schedule, and prompt are required",
            },
            { status: 400 }
          );
        }
        const { stdout } = await execFileAsync(
          "python3",
          [
            SCRIPT,
            "create",
            agent_id,
            "--name",
            name,
            "--schedule",
            schedule,
            "--prompt",
            prompt,
          ],
          { timeout: 15_000, maxBuffer: 1024 * 1024 }
        );
        return NextResponse.json(JSON.parse(stdout));
      }

      default:
        return NextResponse.json(
          {
            success: false,
            error: `Unknown action: ${action}. Valid: pause, resume, remove, edit, create, run`,
          },
          { status: 400 }
        );
    }
  } catch (err: any) {
    console.error("[cron-jobs:POST]", err.message);
    return NextResponse.json(
      { success: false, error: err.message },
      { status: 500 }
    );
  }
}
