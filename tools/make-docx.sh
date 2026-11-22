#!/usr/bin/env bash
# rebuild the docx from the markdown
pandoc EVIDENCE.md -o EVIDENCE.docx --from markdown --syntax-highlighting tango
