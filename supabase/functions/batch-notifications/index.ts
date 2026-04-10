import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (req) => {
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
    });
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    const { issue_id, action, current_upvotes } = await req.json();

    if (action !== "upvote") {
      return new Response(
        JSON.stringify({ message: "Ignored, not an upvote" }),
        { status: 200 }
      );
    }

    // Get issue reporter
    const { data: issue, error: issueError } = await supabaseClient
      .from("issues")
      .select("reporter_id")
      .eq("id", issue_id)
      .single();

    if (issueError || !issue) {
      throw new Error("Issue not found");
    }

    const reporterId = issue.reporter_id;
    const groupKey = `upvote_${issue_id}`;
    
    // Check if there is an unread upvote notification for this issue
    const { data: existingNotifs, error: fetchError } = await supabaseClient
      .from("notifications")
      .select("id, message, metadata, created_at")
      .eq("user_id", reporterId)
      .eq("group_key", groupKey)
      .eq("is_read", false)
      .order("created_at", { ascending: false })
      .limit(1);

    if (fetchError) throw fetchError;

    const existingNotif = existingNotifs?.length > 0 ? existingNotifs[0] : null;

    if (existingNotif) {
      // Check if it was created within the last 5 minutes
      const createdTime = new Date(existingNotif.created_at).getTime();
      const now = new Date().getTime();
      const fiveMinutes = 5 * 60 * 1000;

      if (now - createdTime < fiveMinutes) {
        // Update existing notification instead of creating a new one
        const updatedMessage = `Your issue has reached ${current_upvotes} upvotes!`;
        
        await supabaseClient
          .from("notifications")
          .update({
            message: updatedMessage,
            metadata: {
              ...existingNotif.metadata,
              upvote_count: current_upvotes,
              updated_at: new Date().toISOString()
            }
          })
          .eq("id", existingNotif.id);

        return new Response(
          JSON.stringify({ message: "Notification batched/updated successfully" }),
          { status: 200 }
        );
      }
    }

    // Create a new notification if no recent one exists
    await supabaseClient.from("notifications").insert({
      user_id: reporterId,
      issue_id: issue_id,
      type: "upvote",
      title: "New Upvote",
      message: `Someone upvoted your issue. Total upvotes: ${current_upvotes}`,
      group_key: groupKey,
      metadata: { upvote_count: current_upvotes },
      priority: "low"
    });

    return new Response(
      JSON.stringify({ message: "New notification created successfully" }),
      { status: 200 }
    );
  } catch (err: any) {
    return new Response(JSON.stringify({ error: err.message }), {
      status: 400,
    });
  }
});
