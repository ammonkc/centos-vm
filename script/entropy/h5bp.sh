#!/bin/bash -eux

echo "==> Installing html5-boilerplate apache configs"

cat << 'EOF' > /etc/httpd/conf.d/h5bp.conf
<IfModule mod_mime.c>
    AddType application/json                            json map topojson
    AddType application/ld+json                         jsonld
    AddType application/vnd.geo+json                    geojson
    AddType application/xml                             atom rdf rss xml
    AddType application/javascript                      js
    AddType application/x-web-app-manifest+json         webapp
    AddType text/cache-manifest                         appcache manifest
    AddType audio/mp4                                   f4a f4b m4a
    AddType audio/ogg                                   oga ogg opus
    AddType image/bmp                                   bmp
    AddType image/svg+xml                               svg svgz
    AddType image/webp                                  webp
    AddType video/mp4                                   f4v f4p m4v mp4
    AddType video/ogg                                   ogv
    AddType video/webm                                  webm
    AddType video/x-flv                                 flv
    AddType image/x-icon                                cur ico
    AddType application/font-woff                       woff
    AddType application/font-woff2                      woff2
    AddType application/vnd.ms-fontobject               eot
    AddType application/x-font-ttf                      ttc ttf
    AddType font/opentype                               otf
    AddType application/octet-stream                    safariextz
    AddType application/x-bb-appworld                   bbaw
    AddType application/x-chrome-extension              crx
    AddType application/x-opera-extension               oex
    AddType application/x-xpinstall                     xpi
    AddType text/vcard                                  vcard vcf
    AddType text/vnd.rim.location.xloc                  xloc
    AddType text/vtt                                    vtt
    AddType text/x-component                            htc
</IfModule>

AddDefaultCharset utf-8

<IfModule mod_mime.c>
    AddCharset utf-8 .atom .bbaw .css .geojson .js .json .jsonld .rdf .rss .topojson .vtt .webapp .xloc .xml
</IfModule>

<IfModule mod_deflate.c>
    <IfModule mod_setenvif.c>
        <IfModule mod_headers.c>
            SetEnvIfNoCase ^(Accept-EncodXng|X-cept-Encoding|X{15}|~{15}|-{15})$ ^((gzip|deflate)\s*,?\s*)+|[X~-]{4,13}$ HAVE_Accept-Encoding
            RequestHeader append Accept-Encoding "gzip,deflate" env=HAVE_Accept-Encoding
        </IfModule>
    </IfModule>
    <IfModule mod_filter.c>
        AddOutputFilterByType DEFLATE "application/atom+xml" "application/javascript" "application/json" "application/ld+json" "application/manifest+json" "application/rdf+xml" "application/rss+xml" "application/schema+json" "application/vnd.geo+json" "application/vnd.ms-fontobject" "application/x-font-ttf" "application/x-javascript" "application/x-web-app-manifest+json" "application/xhtml+xml" "application/xml" "font/eot" "font/opentype" "image/bmp" "image/svg+xml" "image/vnd.microsoft.icon" "image/x-icon" "text/cache-manifest" "text/css" "text/html" "text/javascript" "text/plain" "text/vcard" "text/vnd.rim.location.xloc" "text/vtt" "text/x-component" "text/x-cross-domain-policy" "text/xml"
    </IfModule>
    <IfModule mod_mime.c>
        AddEncoding gzip svgz
    </IfModule>
</IfModule>
EOF

