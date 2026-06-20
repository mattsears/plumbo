# frozen_string_literal: true

require "erb"

module Plumbo
  # Builds the self-contained panel markup injected into the page: a scoped
  # <style> block, inline SVG icons, server-rendered file rows, and a vanilla-JS
  # <script>. Everything is namespaced under #plumbo so it can't clash with or
  # leak into the host app's CSS/JS. (Port of the original Tailwind partial +
  # Stimulus controller.)
  module Panel
    # Inline SVGs from Lucide (https://lucide.dev), ISC-licensed. UI icons (:file,
    # :x, :copy) plus per-type row icons keyed by the symbol #category returns.
    # :file doubles as the catch-all row icon.
    ICONS = {
      file: <<~SVG,
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 22h14a2 2 0 0 0 2-2V7l-5-5H6a2 2 0 0 0-2 2v4"/><path d="M14 2v4a2 2 0 0 0 2 2h4"/><path d="m9 18 3-3-3-3"/><path d="m5 12-3 3 3 3"/></svg>
      SVG
      x: <<~SVG,
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M18 6 6 18"/><path d="m6 6 12 12"/></svg>
      SVG
      copy: <<~SVG,
        <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect width="14" height="14" x="8" y="8" rx="2" ry="2"/><path d="M4 16c-1.1 0-2-.9-2-2V4c0-1.1.9-2 2-2h10c1.1 0 2 .9 2 2"/></svg>
      SVG
      controller: <<~SVG,
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="6" cy="19" r="3"/><path d="M9 19h8.5a3.5 3.5 0 0 0 0-7h-11a3.5 3.5 0 0 1 0-7H15"/><circle cx="18" cy="5" r="3"/></svg>
      SVG
      helper: <<~SVG,
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z"/></svg>
      SVG
      layout: <<~SVG,
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect width="18" height="18" x="3" y="3" rx="2"/><path d="M3 9h18"/><path d="M9 21V9"/></svg>
      SVG
      partial: <<~SVG,
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M15.5 11.5 19 8l-3.5-3.5"/><path d="M8.5 12.5 5 16l3.5 3.5"/><path d="m14 4-4 16"/></svg>
      SVG
      view: <<~SVG,
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="16 18 22 12 16 6"/><polyline points="8 6 2 12 8 18"/></svg>
      SVG
      ruby: <<~SVG,
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 3h12l4 6-10 13L2 9Z"/><path d="M11 3 8 9l4 13 4-13-3-6"/><path d="M2 9h20"/></svg>
      SVG
      javascript: <<~SVG,
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M8 3H7a2 2 0 0 0-2 2v5a2 2 0 0 1-2 2 2 2 0 0 1 2 2v5c0 1.1.9 2 2 2h1"/><path d="M16 3h1a2 2 0 0 1 2 2v5a2 2 0 0 0 2 2 2 2 0 0 0-2 2v5a2 2 0 0 1-2 2h-1"/></svg>
      SVG
      copy_all: <<~SVG,
        <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect width="14" height="14" x="8" y="8" rx="2" ry="2"/><path d="M4 16c-1.1 0-2-.9-2-2V4c0-1.1.9-2 2-2h10c1.1 0 2 .9 2 2"/></svg>
      SVG
      clear: <<~SVG,
        <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 6h18"/><path d="M19 6v14c0 1-1 2-2 2H7c-1 0-2-1-2-2V6"/><path d="M8 6V4c0-1 1-2 2-2h4c1 0 2 1 2 2v2"/><line x1="10" x2="10" y1="11" y2="17"/><line x1="14" x2="14" y1="11" y2="17"/></svg>
      SVG
      check: <<~SVG
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20 6 9 17l-5-5"/></svg>
      SVG
    }.freeze

    # Path patterns mapped to icon keys, matched in order. Partials are listed
    # before layouts so a `_partial` living in app/views/layouts still reads as a
    # partial. The first match wins; #category falls back to :file.
    CATEGORY_RULES = [
      [%r{/controllers/.*\.rb\z}, :controller],
      [%r{/helpers/.*\.rb\z}, :helper],
      [%r{/_[^/]+\.erb\z}, :partial],
      [%r{/layouts/}, :layout],
      [/\.erb\z/, :view],
      [/\.js\z/, :javascript],
      [/\.rb\z/, :ruby]
    ].freeze

    CSS = <<~CSS
      #plumbo{position:fixed;z-index:2147483000;bottom:1rem;right:1rem;font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;font-size:12px;line-height:1.4;text-align:left}
      #plumbo *{box-sizing:border-box}
      #plumbo .plumbo-toggle{display:flex;align-items:center;gap:6px;background:#111827;color:#d1d5db;border:1px solid rgba(255,255,255,.1);border-radius:9999px;padding:8px 12px;cursor:pointer;box-shadow:0 10px 15px -3px rgba(0,0,0,.35)}
      #plumbo .plumbo-toggle:hover{background:#1f2937;color:#fff}
      #plumbo .plumbo-panel{position:absolute;bottom:3rem;right:0;width:34rem;max-width:90vw;max-height:70vh;background:#111827;color:#d1d5db;border:1px solid rgba(255,255,255,.1);border-radius:8px;box-shadow:0 25px 50px -12px rgba(0,0,0,.5);display:flex;flex-direction:column;overflow:hidden}
      #plumbo .plumbo-panel[hidden]{display:none}
      #plumbo .plumbo-header{display:flex;align-items:center;justify-content:space-between;padding:10px 16px;border-bottom:1px solid rgba(255,255,255,.1)}
      #plumbo .plumbo-title{font-weight:600;color:#fff;font-size:13px}
      #plumbo .plumbo-actions{display:flex;align-items:center;gap:8px}
      #plumbo button{font:inherit;cursor:pointer;background:transparent;border:0;color:inherit;margin:0}
      #plumbo .plumbo-action{display:flex;align-items:center;color:#9ca3af;padding:4px;border-radius:4px}
      #plumbo .plumbo-action:hover{background:rgba(255,255,255,.1);color:#fff}
      #plumbo .plumbo-close{color:#6b7280;display:flex;padding:2px}
      #plumbo .plumbo-close:hover{color:#fff}
      #plumbo .plumbo-filterbar{display:flex;flex-direction:column;gap:8px;padding:10px 16px;border-bottom:1px solid rgba(255,255,255,.1)}
      #plumbo .plumbo-filter{width:100%;font:inherit;color:#e5e7eb;background:#0b1220;border:1px solid rgba(255,255,255,.1);border-radius:6px;padding:6px 10px}
      #plumbo .plumbo-filter::placeholder{color:#6b7280}
      #plumbo .plumbo-filter:focus{outline:none;border-color:#3b82f6}
      #plumbo .plumbo-chips{display:flex;flex-wrap:nowrap;gap:5px;overflow-x:auto;scrollbar-width:none}
      #plumbo .plumbo-chips::-webkit-scrollbar{display:none}
      #plumbo .plumbo-chip{flex:none;white-space:nowrap;color:#9ca3af;background:rgba(255,255,255,.05);border:1px solid rgba(255,255,255,.1);border-radius:9999px;padding:2px 8px;font-size:10px}
      #plumbo .plumbo-chip:hover{background:rgba(255,255,255,.1);color:#fff}
      #plumbo .plumbo-chip[aria-pressed="true"]{background:#2563eb;border-color:#2563eb;color:#fff}
      #plumbo .plumbo-list{list-style:none;margin:0;padding:0;overflow-y:auto}
      #plumbo .plumbo-row{display:flex;align-items:center;gap:12px;width:100%;padding:8px 16px;color:#d1d5db;text-align:left;border-bottom:1px solid rgba(255,255,255,.05)}
      #plumbo .plumbo-row:hover{background:rgba(255,255,255,.05);color:#fff}
      #plumbo .plumbo-index{width:20px;flex:none;text-align:left;color:#4b5563}
      #plumbo .plumbo-type{flex:none;display:flex;color:#6b7280}
      #plumbo .plumbo-row:hover .plumbo-type{color:#9ca3af}
      #plumbo .plumbo-path{flex:1;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
      #plumbo .plumbo-copy{margin-left:auto;flex:none;color:#4b5563;display:flex}
      #plumbo .plumbo-row:hover .plumbo-copy{color:#9ca3af}
      #plumbo .plumbo-flash{color:#4ade80}
      #plumbo svg{display:block}
    CSS

    JS = <<~JS.freeze
      (function(){
        if (window.__plumboBound) return;
        window.__plumboBound = true;
        var query = "";
        var activeCategory = null;
        var LABELS = { controller:"Controllers", helper:"Helpers", layout:"Layouts", partial:"Partials", view:"Views", javascript:"JavaScript", ruby:"Ruby", file:"Other" };
        var CHECK = '#{ICONS[:check].strip}';
        function copy(text){ if (navigator.clipboard) { navigator.clipboard.writeText(text); } }
        // Briefly swap an icon element's contents for a green check as feedback,
        // leaving the surrounding row (filename, etc.) untouched.
        function flashIcon(el){
          if (!el) return;
          var original = el.innerHTML;
          el.innerHTML = CHECK;
          el.classList.add("plumbo-flash");
          setTimeout(function(){ el.innerHTML = original; el.classList.remove("plumbo-flash"); }, 1200);
        }
        document.addEventListener("click", function(event){
          var root = document.getElementById("plumbo");
          if (!root) return;
          var hit = event.target.closest("[data-plumbo-toggle],[data-plumbo-close],[data-plumbo-copy],[data-plumbo-copy-all],[data-plumbo-clear],[data-plumbo-chip]");
          if (!hit || !root.contains(hit)) return;
          var panel = root.querySelector("[data-plumbo-panel]");
          if (hit.hasAttribute("data-plumbo-toggle")) { panel.hidden = !panel.hidden; }
          else if (hit.hasAttribute("data-plumbo-close")) { panel.hidden = true; }
          else if (hit.hasAttribute("data-plumbo-copy")) {
            copy(hit.getAttribute("data-path")); flashIcon(hit.querySelector(".plumbo-copy"));
          }
          else if (hit.hasAttribute("data-plumbo-copy-all")) {
            copy(visiblePaths(root).join("\\n")); flashIcon(hit);
          }
          else if (hit.hasAttribute("data-plumbo-clear")) {
            var emptied = root.querySelector("#plumbo-list");
            if (emptied) { emptied.innerHTML = ""; renumber(emptied); refresh(); }
          }
          else if (hit.hasAttribute("data-plumbo-chip")) {
            var cat = hit.getAttribute("data-category");
            activeCategory = !cat ? null : (activeCategory === cat ? null : cat);
            refresh();
          }
        });
        document.addEventListener("input", function(event){
          var root = document.getElementById("plumbo");
          var el = event.target;
          if (!root || !el.hasAttribute || !el.hasAttribute("data-plumbo-filter") || !root.contains(el)) return;
          query = el.value || "";
          applyFilter();
        });
        // The data-paths of rows currently visible (after filtering), for Copy All.
        function visiblePaths(root){
          var paths = [];
          var rows = root.querySelectorAll("#plumbo-list > li");
          for (var i = 0; i < rows.length; i++){
            if (rows[i].hidden) continue;
            var button = rows[i].querySelector("[data-path]");
            if (button) paths.push(button.getAttribute("data-path"));
          }
          return paths;
        }
        // Show only rows matching the text query AND the active type chip.
        function applyFilter(){
          var root = document.getElementById("plumbo");
          if (!root) return;
          var q = query.toLowerCase();
          var rows = root.querySelectorAll("#plumbo-list > li");
          for (var i = 0; i < rows.length; i++){
            var button = rows[i].querySelector("[data-path]");
            var path = button ? button.getAttribute("data-path").toLowerCase() : "";
            var cat = button ? button.getAttribute("data-category") : "";
            var matchText = !q || path.indexOf(q) !== -1;
            var matchCat = !activeCategory || cat === activeCategory;
            rows[i].hidden = !(matchText && matchCat);
          }
        }
        // Rebuild the type chips (counts) from the rows currently in the list.
        function buildChips(){
          var root = document.getElementById("plumbo");
          if (!root) return;
          var container = root.querySelector("[data-plumbo-chips]");
          if (!container) return;
          var buttons = root.querySelectorAll("#plumbo-list [data-category]");
          var order = [], counts = {};
          for (var i = 0; i < buttons.length; i++){
            var cat = buttons[i].getAttribute("data-category");
            if (counts[cat] === undefined){ counts[cat] = 0; order.push(cat); }
            counts[cat]++;
          }
          var html = chip(null, "All", buttons.length);
          for (var j = 0; j < order.length; j++){ html += chip(order[j], LABELS[order[j]] || order[j], counts[order[j]]); }
          container.innerHTML = html;
        }
        function chip(cat, label, count){
          var pressed = (activeCategory === cat) ? "true" : "false";
          var attr = (cat === null) ? "" : (' data-category="' + cat + '"');
          return '<button type="button" class="plumbo-chip" data-plumbo-chip' + attr + ' aria-pressed="' + pressed + '">' + label + ' ' + count + '</button>';
        }
        function refresh(){ buildChips(); applyFilter(); }
        // Renumber rows 1..N and sync the count badges to the current row total.
        function renumber(list){
          var rows = list.querySelectorAll(".plumbo-row");
          for (var i = 0; i < rows.length; i++){
            var index = rows[i].querySelector(".plumbo-index");
            if (index) index.textContent = i + 1;
          }
          var counts = document.querySelectorAll("#plumbo .plumbo-count");
          for (var j = 0; j < counts.length; j++){ counts[j].textContent = rows.length; }
        }
        var ICONS = {#{ICONS.map { |key, svg| "#{key}:'#{svg.strip}'" }.join(',')}};
        function escapeHtml(s){ return String(s).replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;").replace(/"/g,"&quot;"); }
        // Build a file row from [path, depth, category], mirroring the server.
        function buildRow(path, depth, category){
          var safe = escapeHtml(path);
          var indent = depth > 0 ? ' style="margin-left:' + (depth * 12) + 'px"' : '';
          var icon = ICONS[category] || ICONS.file;
          return '<li><button type="button" class="plumbo-row" data-plumbo-copy data-path="' + safe + '" data-category="' + escapeHtml(category) + '">'
            + '<span class="plumbo-index"></span>'
            + '<span class="plumbo-type"' + indent + '>' + icon + '</span>'
            + '<span class="plumbo-path">' + safe + '</span>'
            + '<span class="plumbo-copy">' + ICONS.copy + '</span>'
            + '</button></li>';
        }
        // Merge the files from an X-Plumbo-Files header into the panel, skipping
        // paths already listed, then renumber and rebuild chips/filter.
        function mergeFiles(encoded){
          var root = document.getElementById("plumbo");
          if (!root) return;
          var list = root.querySelector("#plumbo-list");
          if (!list) return;
          var data;
          try { data = JSON.parse(atob(encoded)); } catch (e) { return; }
          var seen = {};
          var existing = list.querySelectorAll("[data-path]");
          for (var i = 0; i < existing.length; i++){ seen[existing[i].getAttribute("data-path")] = true; }
          var html = "";
          for (var j = 0; j < data.length; j++){
            var path = data[j][0];
            if (seen[path]) continue;
            seen[path] = true;
            html += buildRow(path, data[j][1], data[j][2]);
          }
          if (html) { list.insertAdjacentHTML("beforeend", html); renumber(list); }
          refresh();
        }
        refresh();
        // Read the file list off every fetch response (Turbo Drive/Frame/Stream
        // and custom fetch all go through fetch) so the panel keeps up without a
        // full reload. Reading a header doesn't consume the response body.
        if (window.fetch){
          var plumboFetch = window.fetch;
          window.fetch = function(){
            return plumboFetch.apply(this, arguments).then(function(response){
              try { var data = response.headers.get("X-Plumbo-Files"); if (data) mergeFiles(data); } catch (e) {}
              return response;
            });
          };
        }
        // A full Turbo Drive visit swaps in a fresh panel; reset the filter to
        // match the new page, then rebuild.
        document.addEventListener("turbo:load", function(){ query = ""; activeCategory = null; refresh(); });
      })();
    JS

    module_function

    # Returns the full panel HTML for the given list of file paths.
    def render(files)
      count = files.size

      <<~HTML
        <div id="plumbo">
          <style>#{CSS}</style>
          #{toggle(count)}
          <div class="plumbo-panel" hidden data-plumbo-panel>
            #{header(count)}
            <div class="plumbo-filterbar">
              <input type="text" class="plumbo-filter" data-plumbo-filter placeholder="Filter files…" aria-label="Filter files">
              <div class="plumbo-chips" data-plumbo-chips></div>
            </div>
            <ol id="plumbo-list" class="plumbo-list" data-plumbo-list>#{rows(files)}</ol>
          </div>
          <script>#{JS}</script>
        </div>
      HTML
    end

    # The always-visible pill that opens the panel and shows how many files
    # rendered the current page.
    def toggle(count)
      <<~HTML
        <button type="button" class="plumbo-toggle" data-plumbo-toggle title="#{count} files used to render this page">
          #{ICONS[:file]}<span class="plumbo-count">#{count}</span>
        </button>
      HTML
    end

    # The panel's title bar, carrying the count and the copy-all/close controls.
    def header(count)
      <<~HTML
        <div class="plumbo-header">
          <span class="plumbo-title">Plumbo (<span class="plumbo-count">#{count}</span>)</span>
          <div class="plumbo-actions">
            <button type="button" class="plumbo-action" data-plumbo-copy-all title="Copy all paths">#{ICONS[:copy_all]}</button>
            <button type="button" class="plumbo-action" data-plumbo-clear title="Clear the list to watch new files as you navigate">#{ICONS[:clear]}</button>
            <button type="button" class="plumbo-close" data-plumbo-close title="Close">#{ICONS[:x]}</button>
          </div>
        </div>
      HTML
    end

    # Builds the numbered <li> rows for a list of files, in render order. Each
    # entry is either a bare path or a [path, depth] pair; depth indents the row
    # to show the parent/child render nesting.
    def rows(files)
      files.each_with_index.map do |entry, index|
        path, depth = Array(entry)
        row(path, index + 1, depth || 0)
      end.join
    end

    # Renders a single click-to-copy file row, numbered by its render order,
    # tagged with its category (so the filter bar can show/hide it by type), and
    # indented by its nesting depth.
    def row(path, index, depth = 0)
      safe = ERB::Util.html_escape(path)
      indent = depth.positive? ? %( style="margin-left:#{depth * 12}px") : ""
      <<~HTML
        <li><button type="button" class="plumbo-row" data-plumbo-copy data-path="#{safe}" data-category="#{category(path)}">
          <span class="plumbo-index">#{index}</span>
          <span class="plumbo-type"#{indent}>#{file_icon(path)}</span>
          <span class="plumbo-path">#{safe}</span>
          <span class="plumbo-copy">#{ICONS[:copy]}</span>
        </button></li>
      HTML
    end

    # Looks up the type icon for a path, falling back to the generic file icon.
    def file_icon(path)
      ICONS.fetch(category(path), ICONS[:file])
    end

    # Classifies a file by its path so each row can show a matching icon,
    # returning the icon key of the first matching rule or :file otherwise.
    def category(path)
      rule = CATEGORY_RULES.find { |pattern, _type| path.match?(pattern) }
      rule ? rule.last : :file
    end
  end
end
