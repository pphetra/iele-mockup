// Student-facing: load today's mock test questions.
// Auth: publishable key (browser). DB: admin client (bypasses RLS).
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "jsr:@supabase/server@^1";

export default {
  fetch: withSupabase({ auth: "publishable" }, async (_req, ctx) => {
    try {
      const { data, error } = await ctx.supabaseAdmin
        .from("current_test")
        .select("questions, updated_at")
        .eq("id", 1)
        .maybeSingle();

      if (error) {
        return Response.json({ error: error.message }, { status: 400 });
      }

      return Response.json({
        success: true,
        questions: data?.questions ?? [],
        updated_at: data?.updated_at ?? null,
      });
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      return Response.json({ error: message }, { status: 400 });
    }
  }),
};
