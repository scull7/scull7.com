# scull7.com developer resources

This page documents the machine-readable surface of Nathan Sculli’s personal resume site and the recruiter-agent product **interview-me**. The static resume (HTML, Markdown, `/resume.json`) is not a generic SaaS console. Interview-me is the OpenAPI / MCP / webhook product for recruiter agents.

## Start here

- [/llms.txt](https://scull7.com/llms.txt) — when to use this site, and links to Markdown pages
- [/llms-full.txt](https://scull7.com/llms-full.txt) — longer resume excerpt
- [/sitemap.xml](https://scull7.com/sitemap.xml) — indexable URLs
- [/robots.txt](https://scull7.com/robots.txt) — crawler policy
- [/resume.json](https://scull7.com/resume.json) — JSON Resume 1.0 source of career facts

## Markdown on the same URL

Pages that have an HTML representation also serve `text/markdown; charset=utf-8` when the request `Accept` header prefers Markdown. Responses include `Vary: Accept`. Clients that reject both HTML and Markdown receive `406 Not Acceptable`. Ordinary browsers that send `text/html` keep getting HTML. Sibling files such as [/index.md](https://scull7.com/index.md) and [/about.md](https://scull7.com/about.md) exist for direct fetch.

## Trust pages

[/about](https://scull7.com/about), [/contact](https://scull7.com/contact), and [/privacy](https://scull7.com/privacy) are static HTML (and Markdown) with the same name, email, and Las Vegas, NV identity as the homepage.

## Interview-me (recruiter agents)

Use interview-me to interview Nathan against published facts and, after work-email verify, request a tentative calendar hold.

- [OpenAPI](https://scull7.com/openapi.json)
- MCP at `/mcp` — tools: `start_interview`, `ask_nathan`, `request_verification`, `create_hold`, `get_resume`
- Optional `callback_url` events: `interview.completed`, `booking.requested`

Company OAuth, practice mode, and live audio/video are not offered. Verify is a human magic-link click; the agent never needs inbox access.

## What is not here

The static resume site does not provision partner API keys or OAuth apps. If you need the recruiter-agent product, use OpenAPI or MCP above. For humans, use [contact](https://scull7.com/contact).

Nathan Sculli · Las Vegas, NV · nathan@vegasbuckeye.com · https://scull7.com
