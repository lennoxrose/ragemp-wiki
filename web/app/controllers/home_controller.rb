class HomeController < ApplicationController
  Item = Struct.new(:label, :href, :external, :count, keyword_init: true)

  # Cards of the main page. Entries point at wiki pages or categories that exist in dist/, or at outside sites.
  LEFT = [
    { title: "Begin your Journey", icon: "compass", items: [
      [:page, "Changelog", "Changelog"], [:page, "Installation Guide", "Getting_Started_with_Server"],
      [:url, "Buy Grand Theft Auto V", "https://www.rockstargames.com/gta-v"]
    ] },
    { title: "Looking forward to help us?", icon: "heart", intro: "You can always help us develop our wiki and improve our community.", items: [
      [:category, "Categorize pages on the wiki", "Uncategorized"], [:category, "Finish incomplete documentation", "Incomplete Functions"],
      [:category, "Add examples to Functions & Events", "Serverside Events"], [:category, "Write tutorials to help newbies", "Tutorials"]
    ] },
    { title: "Community Tools", icon: "wrench", intro: "People that created great tools for RAGE.", items: [
      [:page, "Type-Script Definitions", "Using_Typescript"], [:page, "Development with Visual Studio Code", "Development_with_Visual_Studio_Code"]
    ] },
    { title: "Community Tutorials", icon: "graduation-cap", intro: "Tutorials for various programming aspects of RAGE Multiplayer.", items: [
      [:category, "Browse all tutorials", "Tutorials"], [:page, "FastDL", "FastDL"]
    ] }
  ].freeze

  RIGHT = [
    { title: "NodeJS / JavaScript", icon: "braces", groups: [
      ["Introduction", [[:page, "Getting Started with running a Server", "Getting_Started_with_Server"], [:page, "Getting Started with Development", "Getting_Started_with_Development"],
                        [:page, "Getting Started with Commands", "Getting_Started_with_Commands"], [:page, "Getting Started with Client-side", "Getting_Started_with_Client-side"],
                        [:page, "Getting Started with Events", "Getting_Started_with_Events"]]],
      ["Forum links", [[:url, "Scripting Forum", "https://rage.mp/forums/"], [:url, "Scripting Tutorials", "https://rage.mp/forums/"], [:url, "Scripting Support", "https://rage.mp/forums/"]]]
    ] },
    { title: "TypeScript (Client-side)", icon: "code", items: [
      [:page, "Getting Started with Typescript", "Using_Typescript"], [:page, "Cross Referencing Typescript Files", "Typescript_Imports"]
    ] },
    { title: "JavaScript Help", icon: "circle-help", intro: "These pages link to reference material about JavaScript & NodeJS.", items: [
      [:url, "NodeJS Introduction", "https://nodejs.org/en/learn"], [:url, "NodeJS Docs", "https://nodejs.org/docs/latest/api/"],
      [:url, "JavaScript Introduction", "https://developer.mozilla.org/en-US/docs/Learn_web_development/Core/Scripting"], [:url, "JavaScript Docs", "https://developer.mozilla.org/en-US/docs/Web/JavaScript"]
    ] },
    { title: "Reference", icon: "book", groups: [
      ["JavaScript Server-side", [[:category, "Events", "Serverside Events"], [:category, "Functions", "Serverside API"]]],
      ["JavaScript Client-side", [[:category, "Events", "Client-side Event"], [:category, "Functions", "Clientside API"]]]
    ] }
  ].freeze

  def index_redirect = redirect_to(root_path)

  def show
    @left = LEFT.map { |c| resolve(c) }
    @right = RIGHT.map { |c| resolve(c) }
    @page_count = Wiki.library.count
    @category_count = Wiki.library.categories.size
  end

  private

  # Turns the card definitions into plain items and drops links whose page is not in the mirror.
  def resolve(card)
    card = card.dup
    card[:items] = items(card[:items]) if card[:items]
    card[:groups] = card[:groups].map { |name, list| [name, items(list)] } if card[:groups]
    card
  end

  def items(list)
    counts = Wiki.library.categories.to_h
    list.filter_map do |kind, label, target|
      case kind
      when :page then Wiki.library.slug?(target) ? Item.new(label: label, href: wiki_page_path(target), external: false) : nil
      when :category then counts.key?(target) ? Item.new(label: label, href: category_path(target), external: false, count: counts[target]) : nil
      when :url then Item.new(label: label, href: target, external: true)
      end
    end
  end
end
