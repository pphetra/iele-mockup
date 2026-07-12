// Parent/admin API: upload daily test, fetch history (includes timing).
// Auth: Supabase secret key (auth: 'secret') + custom X-App-Secret header.
// DB: always use supabaseAdmin for privileged access.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "jsr:@supabase/server@^1";

const APP_SECRET = Deno.env.get("APP_SECRET");

type AdminBody = {
  action?: string;
  questions?: unknown[];
};

function unauthorized() {
  return Response.json({ error: "Unauthorized" }, { status: 401 });
}

export default {
  fetch: withSupabase({ auth: "secret" }, async (req, ctx) => {
    try {
      // Second gate: parent-only app secret (not the platform secret key)
      const clientSecret = req.headers.get("X-App-Secret");
      if (!APP_SECRET || clientSecret !== APP_SECRET) {
        return unauthorized();
      }

      if (req.method !== "POST") {
        return Response.json({ error: "Method not allowed" }, { status: 405 });
      }

      const body = (await req.json()) as AdminBody;
      const { action } = body;

      if (action === "upload_test") {
        if (!Array.isArray(body.questions) || body.questions.length === 0) {
          return Response.json(
            { error: "questions must be a non-empty array" },
            { status: 400 },
          );
        }

        const { error } = await ctx.supabaseAdmin.from("current_test").upsert({
          id: 1,
          questions: body.questions,
          updated_at: new Date().toISOString(),
        });

        if (error) throw error;
        return Response.json({
          success: true,
          message: "New test uploaded",
          count: body.questions.length,
        });
      }

      if (action === "get_history") {
        const { data, error } = await ctx.supabaseAdmin
          .from("test_history")
          .select("*")
          .order("test_date", { ascending: false })
          .order("created_at", { ascending: false });

        if (error) throw error;
        return Response.json({ success: true, history: data });
      }

      if (action === "get_current") {
        const { data, error } = await ctx.supabaseAdmin
          .from("current_test")
          .select("*")
          .eq("id", 1)
          .maybeSingle();

        if (error) throw error;
        return Response.json({ success: true, current: data });
      }

      return Response.json(
        {
          error: "Invalid action",
          allowed: ["upload_test", "get_history", "get_current"],
        },
        { status: 400 },
      );
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      return Response.json({ error: message }, { status: 400 });
    }
  }),
};
