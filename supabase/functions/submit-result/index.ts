// Student-facing: save mock test result + per-question timing.
// Auth: publishable key (browser). DB: admin client (bypasses RLS).
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "jsr:@supabase/server@^1";

type SubmitBody = {
  test_date?: string;
  score?: number;
  section_scores?: Record<string, unknown>;
  answers?: Record<string, unknown>;
  weak_areas?: string[];
  timing?: unknown;
};

export default {
  fetch: withSupabase({ auth: "publishable" }, async (req, ctx) => {
    try {
      if (req.method !== "POST") {
        return Response.json({ error: "Method not allowed" }, { status: 405 });
      }

      const body = (await req.json()) as SubmitBody;

      const testDate =
        body.test_date || new Date().toISOString().slice(0, 10);

      const row = {
        test_date: testDate,
        score: typeof body.score === "number" ? body.score : 0,
        section_scores: body.section_scores ?? {},
        answers: body.answers ?? {},
        weak_areas: Array.isArray(body.weak_areas) ? body.weak_areas : [],
        timing: body.timing ?? null,
      };

      const { data, error } = await ctx.supabaseAdmin
        .from("test_history")
        .insert(row)
        .select("id, test_date, score, created_at")
        .single();

      if (error) {
        return Response.json({ error: error.message }, { status: 400 });
      }

      return Response.json({ success: true, result: data });
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      return Response.json({ error: message }, { status: 400 });
    }
  }),
};
