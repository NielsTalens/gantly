# Project Tags + Test Projects Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add project selection tags that load product definition files from `projects/<project>` and submit them with the feature proposal.

**Architecture:** On app start, Sinatra scans `projects/` for subfolders and renders them as tags. The selected tag is posted as `project=<name>`, and the server reads `.md` files from that folder to build the evaluator docs payload.

**Tech Stack:** Ruby (Sinatra), ERB, vanilla JS, CSS, Minitest/Rack::Test

---

### Task 1: Add project discovery + tag rendering in index

**Files:**
- Modify: `app.rb`
- Modify: `views/index.erb`
- Test: `test/app_test.rb`

**Step 1: Write the failing test**

Add a test ensuring tags render when projects exist:

```ruby
  def test_index_renders_project_tags
    get "/"
    assert last_response.ok?
    assert_includes last_response.body, "data-project-tags"
    assert_includes last_response.body, "Sample Product A"
  end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec ruby -Itest test/app_test.rb`
Expected: FAIL with missing tag markup.

**Step 3: Write minimal implementation**

In `app.rb`, add a helper that scans `projects/` for subdirectories and exposes them to the template:

```ruby
PROJECTS_ROOT = File.expand_path("projects", __dir__)

helpers do
  def project_names
    return [] unless Dir.exist?(PROJECTS_ROOT)

    Dir.children(PROJECTS_ROOT)
       .select { |entry| File.directory?(File.join(PROJECTS_ROOT, entry)) }
       .sort
  end
end

get "/" do
  @projects = project_names
  @default_project = @projects.first
  erb :index
end
```

In `views/index.erb`, add a tag bar (top of page) that renders buttons with the project names and a data attribute for JS:

```erb
<div class="project-tags" data-project-tags>
  <% if @projects.empty? %>
    <div class="project-warning">No projects found in /home/nelis/Dev/gareth/projects</div>
  <% else %>
    <% @projects.each do |project| %>
      <button class="project-tag<%= project == @default_project ? " active" : "" %>" data-project="<%= project %>">
        <%= project %>
      </button>
    <% end %>
  <% end %>
</div>
```

**Step 4: Run test to verify it passes**

Run: `bundle exec ruby -Itest test/app_test.rb`
Expected: PASS for the new tag test.

**Step 5: Commit**

```bash
git add app.rb views/index.erb test/app_test.rb
git commit -m "Add project tag rendering"
```

---

### Task 2: Wire tag selection into evaluation request

**Files:**
- Modify: `public/app.js`
- Modify: `public/styles.css`
- Test: `test/app_test.rb`

**Step 1: Write the failing test**

Add a test that ensures the selected project is required:

```ruby
  def test_evaluate_requires_project_param
    post "/evaluate", { feature_proposal: "Test feature" }
    assert_equal 400, last_response.status
    assert_includes last_response.body, "project parameter is required"
  end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec ruby -Itest test/app_test.rb`
Expected: FAIL (current endpoint accepts missing project).

**Step 3: Write minimal implementation**

In `public/app.js`, read the active tag, disable Evaluate if no projects, and include `project` in the form body:

```js
const tagContainer = document.querySelector("[data-project-tags]");
const projectTags = tagContainer ? Array.from(tagContainer.querySelectorAll(".project-tag")) : [];
let selectedProject = projectTags.find((tag) => tag.classList.contains("active"))?.dataset.project || "";

projectTags.forEach((tag) => {
  tag.addEventListener("click", () => {
    projectTags.forEach((btn) => btn.classList.remove("active"));
    tag.classList.add("active");
    selectedProject = tag.dataset.project;
  });
});

if (evaluateButton) {
  evaluateButton.disabled = projectTags.length === 0;
  // ... inside click handler
  if (!selectedProject) {
    alert("Select a project first.");
    return;
  }
  body: new URLSearchParams({ feature_proposal: feature, project: selectedProject })
}
```

In `public/styles.css`, add styles for tag bar and buttons (horizontal, colorized):

```css
.project-tags {
  display: flex;
  gap: 10px;
  flex-wrap: wrap;
  margin-bottom: 20px;
}

.project-tag {
  border: 1px solid rgba(127, 163, 217, 0.45);
  background: var(--panel-2);
  color: var(--text);
  padding: 6px 14px;
  border-radius: 999px;
  cursor: pointer;
  font-weight: 600;
}

.project-tag.active {
  background: var(--accent);
  color: #0b1f40;
}

.project-warning {
  color: var(--danger);
  font-size: 0.92rem;
}
```

**Step 4: Run test to verify it passes**

Run: `bundle exec ruby -Itest test/app_test.rb`
Expected: PASS.

**Step 5: Commit**

```bash
git add public/app.js public/styles.css test/app_test.rb
git commit -m "Wire project selection into evaluate"
```

---

### Task 3: Read docs from selected project folder

**Files:**
- Modify: `app.rb`
- Test: `test/app_test.rb`

**Step 1: Write the failing test**

Add tests for invalid project and missing docs:

```ruby
  def test_evaluate_rejects_unknown_project
    post "/evaluate", { feature_proposal: "Test feature", project: "does-not-exist" }
    assert_equal 400, last_response.status
    assert_includes last_response.body, "Unknown project"
  end

  def test_evaluate_rejects_project_without_md
    post "/evaluate", { feature_proposal: "Test feature", project: "empty_project" }
    assert_equal 400, last_response.status
    assert_includes last_response.body, "No .md files found"
  end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec ruby -Itest test/app_test.rb`
Expected: FAIL.

**Step 3: Write minimal implementation**

In `app.rb`, require `project` param and read `.md` files from the selected folder:

```ruby
DOC_FILES = {
  strategy: "01-strategy.md",
  vision: "02-product-vision.md",
  jtbd: "03-jtbd.md",
  user_flows: "04-user-flows.md",
  product_charter: "05-product-charter.md",
  feedback: "06-feedback.md"
}.freeze

post "/evaluate" do
  content_type :json
  feature = params["feature_proposal"].to_s
  project = params["project"].to_s.strip

  halt 400, { error: "project parameter is required" }.to_json if project.empty?

  project_path = File.join(PROJECTS_ROOT, project)
  halt 400, { error: "Unknown project: #{project}" }.to_json unless Dir.exist?(project_path)

  md_files = Dir.glob(File.join(project_path, "*.md"))
  halt 400, { error: "No .md files found for project #{project}" }.to_json if md_files.empty?

  read_doc = lambda do |path, label|
    File.exist?(path) ? File.read(path) : "No #{label} document provided."
  end

  docs = DOC_FILES.transform_values do |filename|
    label = filename.sub(/\A\d+-/, "").sub(/\.md\z/, "").tr("-", " ")
    read_doc.call(File.join(project_path, filename), label)
  end

  # ... evaluator logic unchanged
end
```

**Step 4: Run test to verify it passes**

Run: `bundle exec ruby -Itest test/app_test.rb`
Expected: PASS.

**Step 5: Commit**

```bash
git add app.rb test/app_test.rb
git commit -m "Load project docs for evaluation"
```

---

### Task 4: Add example projects

**Files:**
- Create: `projects/sample-product-a/01-strategy.md`
- Create: `projects/sample-product-a/02-product-vision.md`
- Create: `projects/sample-product-a/03-jtbd.md`
- Create: `projects/sample-product-a/04-user-flows.md`
- Create: `projects/sample-product-a/05-product-charter.md`
- Create: `projects/sample-product-a/06-feedback.md`
- Create: `projects/sample-product-b/01-strategy.md`
- Create: `projects/sample-product-b/02-product-vision.md`
- Create: `projects/sample-product-b/03-jtbd.md`
- Create: `projects/sample-product-b/04-user-flows.md`
- Create: `projects/sample-product-b/05-product-charter.md`
- Create: `projects/sample-product-b/06-feedback.md`
- Create: `projects/empty_project/.keep`

**Step 1: Write the failing test**

Extend tests so the tag rendering expects these two sample projects:

```ruby
  def test_index_renders_project_tags
    get "/"
    assert last_response.ok?
    assert_includes last_response.body, "sample-product-a"
    assert_includes last_response.body, "sample-product-b"
  end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec ruby -Itest test/app_test.rb`
Expected: FAIL (projects not present yet).

**Step 3: Write minimal implementation**

Create the project folders and minimal `.md` files with short text (ASCII only).

**Step 4: Run test to verify it passes**

Run: `bundle exec ruby -Itest test/app_test.rb`
Expected: PASS.

**Step 5: Commit**

```bash
git add projects test/app_test.rb
git commit -m "Add sample projects"
```

---

### Task 5: Update existing evaluate tests to include project

**Files:**
- Modify: `test/app_test.rb`

**Step 1: Write the failing test**

Adjust existing tests to include the default project and ensure evaluate still returns evaluations:

```ruby
  def test_evaluate_returns_json
    post "/evaluate", { feature_proposal: "Test feature", project: "sample-product-a" }
    assert last_response.ok?
    json = JSON.parse(last_response.body)
    assert json.key?("evaluations")
  end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec ruby -Itest test/app_test.rb`
Expected: FAIL before all tests are updated.

**Step 3: Write minimal implementation**

Update all `/evaluate` tests in `test/app_test.rb` to pass `project: "sample-product-a"`.

**Step 4: Run test to verify it passes**

Run: `bundle exec ruby -Itest test/app_test.rb`
Expected: PASS.

**Step 5: Commit**

```bash
git add test/app_test.rb
git commit -m "Update evaluate tests for project selection"
```

---

### Task 6: Final verification

**Files:**
- None

**Step 1: Run test suite**

Run: `bundle exec ruby -Itest test/app_test.rb`
Expected: PASS (0 failures).

**Step 2: Commit (if needed)**

```bash
git status --short
```
Expected: clean worktree.
