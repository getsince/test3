defmodule T.Repo.Migrations.AddActiveSessionsTrigger do
  use Ecto.Migration

  def change do
    execute """
            CREATE OR REPLACE FUNCTION notify_active_session_changes()
              RETURNS trigger
              LANGUAGE plpgsql
            AS $function$
            BEGIN
              IF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') THEN
                PERFORM pg_notify(
                  'active_sessions_change',
                  json_build_object(
                    'type', TG_OP,
                    'id', NEW.id,
                    'user_id', NEW.user_id,
                    'expires_at', NEW.expires_at
                  )::text
                );

                RETURN NEW;
              ELSE
                PERFORM pg_notify(
                  'active_sessions_change',
                  json_build_object('type', TG_OP,'id', NEW.id)::text
                );

                RETURN OLD;
              END IF;
            END;
            $function$
            """,
            "DROP FUNCTION notify_active_session_changes()"

    execute """
            CREATE TRIGGER notify_active_session_changes_trg
              AFTER INSERT OR UPDATE OR DELETE
              ON active_sessions
              FOR EACH ROW
              EXECUTE PROCEDURE notify_active_session_changes()
            """,
            "DROP TRIGGER notify_active_session_changes_trg ON active_sessions"
  end
end
