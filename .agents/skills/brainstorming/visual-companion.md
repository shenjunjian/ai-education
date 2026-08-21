# Visual Companion Guide

Browser-based visual brainstorming companion，用于展示 mockups、diagrams 和 options。

## When to Use

Per-question 决定，不是 per-session。Test：**would the user understand this better by seeing it than reading it?**

**Use the browser** 当内容本身是 visual 时：

- **UI mockups** — wireframes、layouts、navigation structures、component designs
- **Architecture diagrams** — system components、data flow、relationship maps
- **Side-by-side visual comparisons** — 比较两种 layouts、两种 color schemes、两种 design directions
- **Design polish** — 当问题是 look and feel、spacing、visual hierarchy
- **Spatial relationships** — state machines、flowcharts、entity relationships 渲染为 diagrams

**Use the terminal** 当内容是 text 或 tabular 时：

- **Requirements and scope questions** — "what does X mean?"、"which features are in scope?"
- **Conceptual A/B/C choices** — 用文字描述的 approaches 之间选择
- **Tradeoff lists** — pros/cons、comparison tables
- **Technical decisions** — API design、data modeling、architectural approach selection
- **Clarifying questions** — 答案是 words 而非 visual preference 的任何问题

关于 UI topic 的问题*不*自动是 visual question。"What kind of wizard do you want?" 是 conceptual — 用 terminal。"Which of these wizard layouts feels right?" 是 visual — 用 browser。

## How It Works

Server 监视目录中的 HTML files 并将 newest one 提供给 browser。你将 HTML content 写入 `screen_dir`，user 在 browser 中看到并可点击选择 options。Selections 记录到 `state_dir/events`，你在下一轮读取。

**Content fragments vs full documents:** 如果 HTML file 以 `<!DOCTYPE` 或 `<html` 开头，server 原样 serve（仅 inject helper script）。否则 server 自动将你的 content wrap 在 frame template 中 — 添加 header、CSS theme、connection status 和所有 interactive infrastructure。**默认写 content fragments。** 仅当需要完全控制 page 时才写 full documents。

## Starting a Session

```bash
# Start AFTER the user approves the companion. --open auto-opens their browser on
# the first screen; --project-dir persists mockups and enables same-port restart.
scripts/start-server.sh --project-dir /path/to/project --open

# Returns: {"type":"server-started","port":52341,
#           "url":"http://localhost:52341/?key=ab12…",
#           "screen_dir":"/path/to/project/.superpowers/brainstorm/12345-1706000000/content",
#           "state_dir":"/path/to/project/.superpowers/brainstorm/12345-1706000000/state"}
```

从 response 保存 `screen_dir` 和 `state_dir`。With `--open`，你 push first screen 时 browser 自行打开 — 无需请 user 打开，但仍分享 URL 作为 fallback（headless/remote setups 不会 auto-open）。

**URL 包含 session key（`?key=…`）。** Server 拒绝没有它的任何 request，因此 always 给用户 `url` 字段中的**完整** URL —
never strip query string，never 给出 bare `http://host:port`。Key
gates HTTP 和 WebSocket access，使 stray browser tab 或网络上另一台 machine 无法 read screens 或 inject events。First load 后
browser 通过 cookie 记住 key，因此 reloads 和 `/files/*` assets 无需重复 key。

**Finding connection info:** Server 将 startup JSON 写入 `$STATE_DIR/server-info`。若在 background 启动 server 且未 capture stdout，读该 file 获取 URL 和 port。使用 `--project-dir` 时，检查 `<project>/.superpowers/brainstorm/` 中的 session directory。

**Note:** 将 project root 作为 `--project-dir` 传入，使 mockups 持久化在 `.superpowers/brainstorm/` 并 survive server restarts。Without it，files 去 `/tmp` 并被 cleanup。若尚未存在，提醒 user 将 `.superpowers/` 加入 `.gitignore`。

**Launching the server by platform:**

**Claude Code:**
```bash
# Default mode works — the script backgrounds the server itself.
scripts/start-server.sh --project-dir /path/to/project --open
```

在 Windows 上，script auto-detect 并切换到 foreground mode（阻塞 tool call）。在 Bash tool call 上使用 `run_in_background: true`，使 server survive 跨 conversation turns，然后在下一轮读 `$STATE_DIR/server-info` 获取 URL 和 port。

**Codex:**
```bash
# Codex reaps background processes. The script auto-detects CODEX_CI and
# switches to foreground mode. Run it normally — no extra flags needed.
scripts/start-server.sh --project-dir /path/to/project --open
```

**Gemini CLI:**
```bash
# Use --foreground and set is_background: true on your shell tool call
# so the process survives across turns
scripts/start-server.sh --project-dir /path/to/project --open --foreground
```

**Copilot CLI:**
```bash
# Start it with Copilot CLI's non-blocking/background shell mechanism so the
# server survives across turns. Keep --foreground so the harness, not the
# script, owns backgrounding. The launcher is a .sh, so invoke it via bash
# (on Windows, call Git Bash's bash.exe from the PowerShell tool).
bash scripts/start-server.sh --project-dir /path/to/project --open --foreground
```

**Other environments:** Server 必须在 conversation turns 间 keep running in background。若 environment reaps detached processes，使用 `--foreground` 并用 platform 的 background execution mechanism 启动 command。

若 URL 从你的 browser unreachable（remote/containerized setups 常见），bind non-loopback host：

```bash
scripts/start-server.sh \
  --project-dir /path/to/project \
  --host 0.0.0.0 \
  --url-host localhost
```

用 `--url-host` 控制 returned URL JSON 中 printed 的 hostname。

## The Loop

1. **Check server is alive**，然后 **write HTML** 到 `screen_dir` 中的新 file：
   - **Required: 在引用 URL 或 push screen 之前 confirm server is alive。** 检查 `$STATE_DIR/server-info` 存在且 `$STATE_DIR/server-stopped` 不存在。若已 shutdown，用 `start-server.sh` 和**相同 `--project-dir`** restart — 它 reuse 相同 port，user 的 open tab 自行 reconnect（server down 时显示 "paused" overlay），无需发新 URL。Server 在 idle 4 小时后 auto-exit（可用 `--idle-timeout-minutes` 配置）。
   - 使用 semantic filenames：`platform.html`、`visual-style.html`、`layout.html`
   - **Never reuse filenames** — 每个 screen 是新 file
   - 使用 file-creation tool — **never use cat/heredoc**（dumps noise into terminal）
   - Server 自动 serve newest file

2. **Tell user what to expect and end your turn:**
   - 每步提醒 URL（不只是 first）
   - 简要 text summary 屏幕上有什么（例如 "Showing 3 layout options for the homepage"）
   - 请他们在 terminal 回复："Take a look and let me know what you think. Click to select an option if you'd like."

3. **On your next turn** — user 在 terminal 回复后：
   - 若存在则读 `$STATE_DIR/events` — 包含 user 的 browser interactions（clicks、selections）为 JSON lines
   - 与 user 的 terminal text merge 得到完整 picture
   - Terminal message 是 primary feedback；`state_dir/events` 提供 structured interaction data

4. **Iterate or advance** — 若 feedback 改变 current screen，写新 file（例如 `layout-v2.html`）。仅当 current step validated 才进入下一问题。

5. **Unload when returning to terminal** — 当下一步不需要 browser（例如 clarifying question、tradeoff discussion），push waiting screen 清除 stale content：

   ```html
   <!-- filename: waiting.html (or waiting-2.html, etc.) -->
   <div style="display:flex;align-items:center;justify-content:center;min-height:60vh">
     <p class="subtitle">Continuing in terminal...</p>
   </div>
   ```

   这防止 user 盯着已 resolved 的选择而 conversation 已继续。下一 visual question 出现时，照常 push 新 content file。

6. Repeat until done.

## Writing Content Fragments

只写 page 内部的内容。Server 自动 wrap 在 frame template 中（header、theme CSS、connection status 和所有 interactive infrastructure）。

**Minimal example:**

```html
<h2>Which layout works better?</h2>
<p class="subtitle">Consider readability and visual hierarchy</p>

<div class="options">
  <div class="option" data-choice="a" onclick="toggleSelect(this)">
    <div class="letter">A</div>
    <div class="content">
      <h3>Single Column</h3>
      <p>Clean, focused reading experience</p>
    </div>
  </div>
  <div class="option" data-choice="b" onclick="toggleSelect(this)">
    <div class="letter">B</div>
    <div class="content">
      <h3>Two Column</h3>
      <p>Sidebar navigation with main content</p>
    </div>
  </div>
</div>
```

就这样。无需 `<html>`、CSS、`<script>` tags。Server 提供全部。

## CSS Classes Available

Frame template 为你的 content 提供这些 CSS classes：

### Options (A/B/C choices)

```html
<div class="options">
  <div class="option" data-choice="a" onclick="toggleSelect(this)">
    <div class="letter">A</div>
    <div class="content">
      <h3>Title</h3>
      <p>Description</p>
    </div>
  </div>
</div>
```

**Multi-select:** 在 container 上添加 `data-multiselect` 让用户选择多个 options。每次 click toggles item 的 selected styling。

```html
<div class="options" data-multiselect>
  <!-- same option markup — users can select/deselect multiple -->
</div>
```

### Cards (visual designs)

```html
<div class="cards">
  <div class="card" data-choice="design1" onclick="toggleSelect(this)">
    <div class="card-image"><!-- mockup content --></div>
    <div class="card-body">
      <h3>Name</h3>
      <p>Description</p>
    </div>
  </div>
</div>
```

### Mockup container

```html
<div class="mockup">
  <div class="mockup-header">Preview: Dashboard Layout</div>
  <div class="mockup-body"><!-- your mockup HTML --></div>
</div>
```

### Split view (side-by-side)

```html
<div class="split">
  <div class="mockup"><!-- left --></div>
  <div class="mockup"><!-- right --></div>
</div>
```

### Pros/Cons

```html
<div class="pros-cons">
  <div class="pros"><h4>Pros</h4><ul><li>Benefit</li></ul></div>
  <div class="cons"><h4>Cons</h4><ul><li>Drawback</li></ul></div>
</div>
```

### Mock elements (wireframe building blocks)

```html
<div class="mock-nav">Logo | Home | About | Contact</div>
<div style="display: flex;">
  <div class="mock-sidebar">Navigation</div>
  <div class="mock-content">Main content area</div>
</div>
<button class="mock-button">Action Button</button>
<input class="mock-input" placeholder="Input field">
<div class="placeholder">Placeholder area</div>
```

### Typography and sections

- `h2` — page title
- `h3` — section heading
- `.subtitle` — title 下方 secondary text
- `.section` — 带 bottom margin 的 content block
- `.label` — small uppercase label text

## Browser Events Format

User 在 browser 中 click options 时，interactions 记录到 `$STATE_DIR/events`（每行一个 JSON object）。Push new screen 时 file 自动 cleared。

```jsonl
{"type":"click","choice":"a","text":"Option A - Simple Layout","timestamp":1706000101}
{"type":"click","choice":"c","text":"Option C - Complex Grid","timestamp":1706000108}
{"type":"click","choice":"b","text":"Option B - Hybrid","timestamp":1706000115}
```

完整 event stream 显示 user 的 exploration path — 他们可能 click 多个 options 才 settle。Last `choice` event 通常是 final selection，但 click pattern 可 reveal hesitation 或 preferences worth asking about。

若 `$STATE_DIR/events` 不存在，user 未与 browser 交互 — 仅用 terminal text。

## Design Tips

- **Scale fidelity to the question** — layout 用 wireframes，polish 问题用 polish
- **Explain the question on each page** — "Which layout feels more professional?" 而非只是 "Pick one"
- **Iterate before advancing** — 若 feedback 改变 current screen，写新版本
- **2-4 options max** per screen
- **Use real content when it matters** — 摄影 portfolio 用 actual images（Unsplash）。Placeholder content 掩盖 design issues。
- **Keep mockups simple** — 聚焦 layout 和 structure，非 pixel-perfect design

## File Naming

- 使用 semantic names：`platform.html`、`visual-style.html`、`layout.html`
- Never reuse filenames — 每个 screen 必须是新 file
- Iterations：append version suffix 如 `layout-v2.html`、`layout-v3.html`
- Server 按 modification time serve newest file

## Cleaning Up

```bash
scripts/stop-server.sh $SESSION_DIR
```

若 session 用了 `--project-dir`，mockup files 持久化在 `.superpowers/brainstorm/` 供 later reference。Only `/tmp` sessions 在 stop 时 deleted。

## Reference

- Frame template (CSS reference): `scripts/frame-template.html`
- Helper script (client-side): `scripts/helper.js`
