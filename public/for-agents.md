# scull7.com developer resources

This page documents the machine-readable surface of Nathan Sculli’s personal resume site. It does not describe a product API, an MCP server, OAuth, or webhooks — those are not operated here.

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

## What is not here

There is no `/api`, no OpenAPI document, no MCP endpoint, and no webhook receiver. If a tool asks for those, it has the wrong host. Use [contact](https://scull7.com/contact) for humans.

Nathan Sculli · Las Vegas, NV · nathan@vegasbuckeye.com · https://scull7.com
