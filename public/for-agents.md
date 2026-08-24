# scull7.com developer resources

This page documents the machine-readable surface of Nathan Sculli’s personal resume site and the recruiter-agent product **interview-me**. The static resume (HTML, Markdown, `/resume.json`) is not a generic SaaS console. Interview-me is the OpenAPI / MCP product for recruiter agents who start a named session and ask cited questions.

## Start here

- [/llms.txt](https://scull7.com/llms.txt) — when to use the static resume versus interview-me
- [/llms-full.txt](https://scull7.com/llms-full.txt) — longer resume excerpt
- [/sitemap.xml](https://scull7.com/sitemap.xml) — indexable URLs
- [/robots.txt](https://scull7.com/robots.txt) — crawler policy
- [/resume.json](https://scull7.com/resume.json) — JSON Resume 1.0 source of career facts
- [/openapi.json](https://scull7.com/openapi.json) — interview-me HTTP contract
- [/mcp](https://scull7.com/mcp) — interview-me MCP tools list

## Markdown on the same URL

Pages that have an HTML representation also serve `text/markdown; charset=utf-8` when the request `Accept` header prefers Markdown. Responses include `Vary: Accept`. Clients that reject both HTML and Markdown receive `406 Not Acceptable`. Ordinary browsers that send `text/html` keep getting HTML. Sibling files such as [/index.md](https://scull7.com/index.md) and [/about.md](https://scull7.com/about.md) exist for direct fetch.

## Trust pages

[/about](https://scull7.com/about), [/contact](https://scull7.com/contact), and [/privacy](https://scull7.com/privacy) are static HTML (and Markdown) with the same name, email, and Las Vegas, NV identity as the homepage.

## Interview-me

Use interview-me to start a named session (`company`, `role`, `recruiter_name`, `work_email`) and ask questions against published facts. Unpublished facts are refused. Search experience with `GET /interview/experience?q=`. Contact remains nathan@vegasbuckeye.com. No street address is published.

Company OAuth is not offered. For humans, use [contact](https://scull7.com/contact).

Nathan Sculli · Las Vegas, NV · nathan@vegasbuckeye.com · https://scull7.com
