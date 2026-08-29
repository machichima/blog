---
title: "{{ replace .File.ContentBaseName "-" " " | title }}"
summary: ""
description: ""
date: {{ .Date }}
slug: "{{ .File.Dir | replaceRE `^content/` "" | replaceRE `[0-9]{4}-[0-9]{2}-[0-9]{2}-` "" | replaceRE "/$" "" | replaceRE `^.+\/` "" }}"
tags: ["Ray"]
# series: ["Documentation"]
# categories: ["Introduction"]
# series_order: 1
cascade:
  showSummary: true
  hideFeatureImage: false
draft: false
---
