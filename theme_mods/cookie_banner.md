Create partial page `themes/loveit/layouts/partials/head/cookie.html`.
```html
<!-- Start cookieyes banner -->
<script id="cookieyes" type="text/javascript" src="https://cdn-cookieyes.com/client_data/806451328eca53aeb54fc166/script.js"></script>
<!-- End cookieyes banner -->
```

Update `themes/loveit/layouts/_default/baseof.html` with in `head` section.
```html
{{- partial "head/cookie.html" . -}}
```