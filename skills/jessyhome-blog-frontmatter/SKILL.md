---
name: jessyhome-blog-frontmatter
description: Prepare JessyHome Astro blog posts by adding default YAML frontmatter to new Markdown or MDX files in src/data/post. Use when a user asks to add, normalize, generate, repair, or check blog frontmatter for the JessyHome/AstroWind blog, especially before build, deploy, or CMS review.
---

# JessyHome Blog Frontmatter

Use this skill only inside `/Users/jessyhuang/Documents/JessyHome`.

## Workflow

1. Put new `.md` or `.mdx` blog files in `src/data/post`.
2. Run `npm run posts:frontmatter` from the repository root.
3. Review the command output:
   - `UPDATED` means frontmatter was inserted.
   - `UNCHANGED` means frontmatter already existed and contained `title`.
   - `ERROR` means existing frontmatter is missing required `title`; fix that file manually.
4. If code changed, run `npm run build` and `npm run check` before reporting completion.

## Behavior

The script only processes files already in `src/data/post`; do not import from external blog directories.

For files without frontmatter, it injects:

```yaml
title: "<first H1, else first H2, else first H3, else filename>"
excerpt: ''
category: Engineering
tags: []
image: ''
publishDate: <current system date YYYY-MM-DD>
author: Jessy Huang
draft: true
```

For files with existing frontmatter, it does not edit the file. It only checks whether `title` exists, because Astro's post schema requires `title`.
