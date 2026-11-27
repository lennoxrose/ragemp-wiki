Rails.application.routes.draw do
  root "home#show"

  get "login", to: "sessions#new"
  post "login", to: "sessions#create"
  delete "logout", to: "sessions#destroy"
  get "register", to: "registrations#new"
  post "register", to: "registrations#create"

  get "search", to: "search#index"
  get "categories/:name", to: "categories#show", as: :category, constraints: { name: /[^\/]+/ }, format: false
  get "map", to: "map#show"
  patch "appearance", to: "appearance#update"

  # Wiki pages. The slug is the page title with spaces as underscores, e.g. /wiki/Player::kick
  scope "wiki", constraints: { slug: /[^\/]+/ }, format: false do
    get ":slug", to: "pages#show", as: :wiki_page
    get ":slug/source", to: "pages#source", as: :wiki_source
    get ":slug/raw", to: "pages#raw", as: :wiki_raw
    get ":slug/discussion", to: "topics#index", as: :wiki_discussion
    post ":slug/topics", to: "topics#create", as: :wiki_topics
  end
  resources :topics, only: %i[update destroy] do
    resources :posts, only: :create
  end
  resources :posts, only: :destroy do
    post :like, on: :member
  end

  # Members
  resource :account, only: :show
  scope "account" do
    get "contributions", to: "accounts#contributions", as: :contributions
    get "settings", to: "settings#show", as: :settings
    patch "settings/profile", to: "settings#update_profile", as: :settings_profile
    patch "settings/email", to: "settings#update_email", as: :settings_email
    patch "settings/password", to: "settings#update_password", as: :settings_password
    patch "settings/notifications", to: "settings#update_notifications", as: :settings_notifications
    delete "settings/sessions/:id", to: "settings#destroy_session", as: :settings_session
    delete "settings/sessions", to: "settings#destroy_other_sessions", as: :settings_sessions
    delete "settings", to: "settings#destroy", as: :delete_account
    resources :tokens, only: %i[create destroy], controller: "api_tokens", as: :api_tokens
  end
  get "members/:username", to: "members#show", as: :member, constraints: { username: /[a-z0-9_]+/ }

  # Internal API for the site's own pages, the wikisync application, and the public token API.
  namespace :api do
    namespace :v1 do
      get "graph", to: "graph#show"
      get "search", to: "search#index"
      get "sync/status", to: "sync#status"
    end
    namespace :v2 do
      get "sync/config", to: "sync#options"
      post "sync/runs", to: "sync#create"
      post "sync/runs/:id/claim", to: "sync#claim"
      post "sync/runs/:id/events", to: "sync#events"
      post "sync/runs/:id/files", to: "sync#files"
      post "sync/runs/:id/finish", to: "sync#finish"
      post "sync/refresh", to: "sync#refresh"
    end
    namespace :v3 do
      get "me", to: "me#show"
      get "pages", to: "pages#index"
      get "pages/:slug", to: "pages#show", as: :page, constraints: { slug: /[^\/]+/ }, format: false
      get "categories", to: "categories#index"
      get "categories/:name", to: "categories#show", as: :category, constraints: { name: /[^\/]+/ }, format: false
      get "search", to: "search#index"
      get "graph", to: "graph#show"
    end
  end

  namespace :admin do
    root "analytics#show"
    get "export", to: "analytics#export"
    resources :users, only: %i[index update destroy] do
      member do
        post :disable
        post :enable
        post :reset_password
      end
    end
    resources :invites, only: %i[create destroy]
    resource :sync, only: :show, controller: "sync" do
      post :run
      post :stop
      patch :settings
      get :log
    end
  end
end
