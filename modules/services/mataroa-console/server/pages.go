package main

import (
	"fmt"
	"html"
	"strings"
)

const style = `
:root{--ink:#16130f;--paper:#faf7f0;--muted:#6d6558;--accent:#b23b1d;--line:#ddd5c6}
*{box-sizing:border-box}
body{margin:0;background:var(--paper);color:var(--ink);
 font:16px/1.62 ui-serif,Georgia,serif}
header,main{max-width:60rem;margin:0 auto;padding:1.4rem 1.2rem}
header{display:flex;gap:1rem;align-items:baseline;flex-wrap:wrap;
 border-bottom:1px solid var(--line)}
header b{font:600 .78rem/1.4 ui-monospace,monospace;letter-spacing:.16em;text-transform:uppercase}
header a{color:var(--accent);text-decoration:none}
header .sp{flex:1}
nav a{margin-right:.9rem}
table{border-collapse:collapse;width:100%;font-size:.92rem}
td,th{padding:.42rem .5rem;border-bottom:1px solid var(--line);text-align:left;vertical-align:top}
th{font:400 .68rem/1.4 ui-monospace,monospace;letter-spacing:.12em;text-transform:uppercase;color:var(--muted)}
code,pre{font-family:ui-monospace,SFMono-Regular,monospace;font-size:.86rem}
pre{background:#f2ece0;padding:.8rem;overflow:auto}
a{color:var(--accent)}
input[type=text],input[type=date],textarea{width:100%;padding:.55rem;border:1px solid var(--line);
 background:#fffdf7;color:inherit;font:inherit}
textarea{min-height:26rem;font-family:ui-monospace,monospace;font-size:.88rem;line-height:1.55}
button{padding:.5rem .9rem;border:1px solid var(--ink);background:var(--ink);color:var(--paper);
 font:600 .74rem/1 ui-monospace,monospace;letter-spacing:.1em;text-transform:uppercase;cursor:pointer}
button.ghost{background:transparent;color:var(--ink)}
.row{display:grid;grid-template-columns:1fr auto;gap:1rem;align-items:end;margin-bottom:1rem}
.badge{font:400 .7rem/1.4 ui-monospace,monospace;padding:.1rem .45rem;border:1px solid var(--line);color:var(--muted)}
.badge.sync{border-color:#7a9b6a;color:#4d6b3f}
.badge.differs{border-color:#c58a2a;color:#8a5f15}
.badge.local-only{border-color:#9a9a9a}
.badge.remote-only{border-color:var(--accent);color:var(--accent)}
.note{color:var(--muted);font-size:.9rem}
.err{color:var(--accent)}
.actions{display:flex;gap:.6rem;flex-wrap:wrap;margin:1.2rem 0}
`

func esc(value any) string { return html.EscapeString(fmt.Sprint(value)) }

func (c *config) page(title, body string) []byte {
	blog := c.blogURL
	if blog == "" {
		blog = "mataroa.blog"
	}
	return []byte(fmt.Sprintf(`<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>%s</title><style>%s</style></head>
<body><header><b>mataroa console</b><nav>
<a href="/">ledger</a><a href="/e/new">new post</a>
</nav><span class="sp"></span>
<span class="note">%s</span>
</header><main>%s</main></body></html>
`, esc(title), style, esc(blog), body))
}

func (c *config) ledgerPage(data ledgerData) []byte {
	var rows strings.Builder
	for _, row := range data.Posts {
		rows.WriteString(`<tr><td><a href="/p/` + esc(row.Slug) + `">` + esc(row.Title) + `</a></td>`)
		rows.WriteString(`<td><span class="badge ` + esc(row.State) + `">` + esc(row.State) + `</span></td>`)
		published := row.PublishedAt
		if published == "" {
			published = "draft"
		}
		rows.WriteString(`<td>` + esc(published) + `</td>`)
		rows.WriteString(`<td><a href="/e/` + esc(row.Slug) + `">edit</a>`)
		if row.URL != "" {
			rows.WriteString(` · <a href="` + esc(row.URL) + `">live</a>`)
		}
		rows.WriteString(`</td></tr>`)
	}
	errorHTML := ""
	if data.Error != "" {
		errorHTML = `<p class="err">remote: ` + esc(data.Error) + `</p>`
	}
	table := rows.String()
	if table == "" {
		table = `<tr><td colspan="4" class="note">no posts yet</td></tr>`
	}
	body := `<h1>Posts</h1>
<p class="note">` + fmt.Sprint(len(data.Posts)) + ` local files · ` + fmt.Sprint(data.RemoteCount) + ` on the blog.
<div class="actions">
<form method="post" action="/pull"><button class="ghost">Pull remote-only</button></form>
</div>
` + errorHTML + `
<table><thead><tr><th>title</th><th>state</th><th>published</th><th></th></tr></thead>
<tbody>` + table + `</tbody></table>`
	return c.page("mataroa console", body)
}

func (c *config) editorPage(current *post, slug string) []byte {
	if current == nil {
		current = &post{}
	}
	heading := "New post"
	if current.Title != "" {
		heading = "Edit"
	}
	body := `<h1>` + heading + `</h1>
<form method="post" action="/save">
<input type="hidden" name="slug" value="` + esc(slug) + `">
<div class="row"><div><label class="note">title</label>
<input type="text" name="title" value="` + esc(current.Title) + `" autofocus></div>
<div><label class="note">published</label>
<input type="date" name="published_at" value="` + esc(current.PublishedAt) + `"></div></div>
<label class="note">markdown</label>
<textarea name="body" spellcheck="false">` + esc(current.Body) + `</textarea>
<div class="actions">
<button>save file</button>
<button class="ghost" formaction="/publish">save and publish</button>
<button class="ghost" formaction="/unpublish">unpublish</button>
</div></form>
<p class="note">Files live in <code>posts/&lt;slug&gt;.md</code> on the host. Saving
commits the change; publishing sends it to mataroa and takes its slug back.</p>`
	return c.page("edit "+slug, body)
}

func (c *config) postPage(current post) []byte {
	published := current.PublishedAt
	if published == "" {
		published = "draft"
	}
	body := `<h1>` + esc(current.Title) + `</h1>
<p class="note">` + esc(published) + ` · <code>` + esc(current.Slug) + `</code>
· <a href="/e/` + esc(current.Slug) + `">edit</a></p>
<article>` + c.render(current.Body) + `</article>`
	return c.page(current.Title, body)
}
