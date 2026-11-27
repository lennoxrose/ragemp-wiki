# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_11_28_000009) do
  create_table "active_storage_attachments", charset: "utf8mb4", collation: "utf8mb4_uca1400_ai_ci", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", charset: "utf8mb4", collation: "utf8mb4_uca1400_ai_ci", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", charset: "utf8mb4", collation: "utf8mb4_uca1400_ai_ci", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "admin_events", charset: "utf8mb4", collation: "utf8mb4_uca1400_ai_ci", force: :cascade do |t|
    t.bigint "actor_id"
    t.string "action", null: false
    t.string "subject"
    t.datetime "created_at", null: false
    t.index ["actor_id"], name: "index_admin_events_on_actor_id"
    t.index ["created_at"], name: "index_admin_events_on_created_at"
  end

  create_table "api_tokens", charset: "utf8mb4", collation: "utf8mb4_uca1400_ai_ci", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "name", null: false
    t.string "token_digest", null: false
    t.string "last4", null: false
    t.string "scope", default: "read", null: false
    t.datetime "expires_at"
    t.datetime "revoked_at"
    t.datetime "last_used_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["token_digest"], name: "index_api_tokens_on_token_digest", unique: true
    t.index ["user_id"], name: "index_api_tokens_on_user_id"
  end

  create_table "invite_codes", charset: "utf8mb4", collation: "utf8mb4_uca1400_ai_ci", force: :cascade do |t|
    t.string "code", null: false
    t.bigint "created_by_id"
    t.bigint "used_by_id"
    t.datetime "used_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "revoked_at"
    t.index ["code"], name: "index_invite_codes_on_code", unique: true
    t.index ["created_by_id"], name: "index_invite_codes_on_created_by_id"
    t.index ["used_by_id"], name: "index_invite_codes_on_used_by_id", unique: true
  end

  create_table "login_attempts", charset: "utf8mb4", collation: "utf8mb4_uca1400_ai_ci", force: :cascade do |t|
    t.bigint "user_id"
    t.string "outcome", null: false
    t.datetime "created_at", null: false
    t.index ["created_at"], name: "index_login_attempts_on_created_at"
    t.index ["user_id"], name: "index_login_attempts_on_user_id"
  end

  create_table "page_views", charset: "utf8mb4", collation: "utf8mb4_uca1400_ai_ci", force: :cascade do |t|
    t.bigint "user_id"
    t.datetime "created_at", null: false
    t.string "page_slug", collation: "utf8mb4_bin"
    t.index ["created_at"], name: "index_page_views_on_created_at"
    t.index ["page_slug", "created_at"], name: "index_page_views_on_page_slug_and_created_at"
    t.index ["user_id"], name: "index_page_views_on_user_id"
  end

  create_table "post_likes", charset: "utf8mb4", collation: "utf8mb4_uca1400_ai_ci", force: :cascade do |t|
    t.bigint "post_id", null: false
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.index ["post_id", "user_id"], name: "index_post_likes_on_post_id_and_user_id", unique: true
    t.index ["post_id"], name: "index_post_likes_on_post_id"
    t.index ["user_id"], name: "index_post_likes_on_user_id"
  end

  create_table "posts", charset: "utf8mb4", collation: "utf8mb4_uca1400_ai_ci", force: :cascade do |t|
    t.bigint "topic_id", null: false
    t.bigint "user_id"
    t.bigint "parent_id"
    t.text "body", null: false
    t.integer "likes_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["parent_id"], name: "index_posts_on_parent_id"
    t.index ["topic_id"], name: "index_posts_on_topic_id"
    t.index ["user_id"], name: "index_posts_on_user_id"
  end

  create_table "search_logs", charset: "utf8mb4", collation: "utf8mb4_uca1400_ai_ci", force: :cascade do |t|
    t.bigint "user_id"
    t.string "query", null: false
    t.integer "results_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.index ["created_at"], name: "index_search_logs_on_created_at"
    t.index ["user_id"], name: "index_search_logs_on_user_id"
  end

  create_table "sync_runs", charset: "utf8mb4", collation: "utf8mb4_uca1400_ai_ci", force: :cascade do |t|
    t.string "trigger", default: "manual", null: false
    t.bigint "triggered_by_id"
    t.string "mode", default: "vault", null: false
    t.boolean "full", default: false, null: false
    t.string "status", default: "running", null: false
    t.string "phase"
    t.integer "listed", default: 0, null: false
    t.integer "total", default: 0, null: false
    t.integer "changed_count", default: 0, null: false
    t.integer "removed", default: 0, null: false
    t.integer "done", default: 0, null: false
    t.integer "written", default: 0, null: false
    t.integer "failed", default: 0, null: false
    t.integer "batches", default: 0, null: false
    t.text "error"
    t.text "log", size: :medium
    t.datetime "started_at", null: false
    t.datetime "finished_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "pid"
    t.index ["started_at"], name: "index_sync_runs_on_started_at"
    t.index ["triggered_by_id"], name: "index_sync_runs_on_triggered_by_id"
  end

  create_table "sync_settings", charset: "utf8mb4", collation: "utf8mb4_uca1400_ai_ci", force: :cascade do |t|
    t.boolean "enabled", default: false, null: false
    t.string "frequency", default: "daily", null: false
    t.string "run_at", default: "03:00", null: false
    t.string "time_zone", default: "Europe/Berlin", null: false
    t.string "cron"
    t.string "mode", default: "vault", null: false
    t.integer "batch", default: 50, null: false
    t.integer "namespace", default: 0, null: false
    t.boolean "weekly_full", default: false, null: false
    t.datetime "next_run_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "topics", charset: "utf8mb4", collation: "utf8mb4_uca1400_ai_ci", force: :cascade do |t|
    t.bigint "user_id"
    t.string "title", null: false
    t.string "status", default: "open", null: false
    t.boolean "pinned", default: false, null: false
    t.integer "posts_count", default: 0, null: false
    t.datetime "last_activity_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "page_slug", default: "", null: false, collation: "utf8mb4_bin"
    t.index ["page_slug"], name: "index_topics_on_page_slug"
    t.index ["user_id"], name: "index_topics_on_user_id"
  end

  create_table "user_sessions", charset: "utf8mb4", collation: "utf8mb4_uca1400_ai_ci", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "token_digest", null: false
    t.string "user_agent"
    t.string "ip"
    t.datetime "last_active_at", null: false
    t.datetime "created_at", null: false
    t.index ["token_digest"], name: "index_user_sessions_on_token_digest", unique: true
    t.index ["user_id"], name: "index_user_sessions_on_user_id"
  end

  create_table "users", charset: "utf8mb4", collation: "utf8mb4_uca1400_ai_ci", force: :cascade do |t|
    t.string "email", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "role", default: "member", null: false
    t.string "username"
    t.string "display_name"
    t.string "bio", limit: 160
    t.datetime "disabled_at"
    t.datetime "last_seen_at"
    t.text "preferences", size: :long, collation: "utf8mb4_bin"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["role"], name: "index_users_on_role"
    t.index ["username"], name: "index_users_on_username", unique: true
    t.check_constraint "json_valid(`preferences`)", name: "preferences"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "admin_events", "users", column: "actor_id", on_delete: :nullify
  add_foreign_key "api_tokens", "users", on_delete: :cascade
  add_foreign_key "invite_codes", "users", column: "created_by_id"
  add_foreign_key "invite_codes", "users", column: "used_by_id"
  add_foreign_key "login_attempts", "users", on_delete: :nullify
  add_foreign_key "page_views", "users", on_delete: :nullify
  add_foreign_key "post_likes", "posts", on_delete: :cascade
  add_foreign_key "post_likes", "users", on_delete: :cascade
  add_foreign_key "posts", "posts", column: "parent_id", on_delete: :cascade
  add_foreign_key "posts", "topics", on_delete: :cascade
  add_foreign_key "posts", "users", on_delete: :nullify
  add_foreign_key "search_logs", "users", on_delete: :nullify
  add_foreign_key "sync_runs", "users", column: "triggered_by_id", on_delete: :nullify
  add_foreign_key "topics", "users", on_delete: :nullify
  add_foreign_key "user_sessions", "users", on_delete: :cascade
end
