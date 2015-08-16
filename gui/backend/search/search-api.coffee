###
# Search
###

fs = require "fs"
util = require "util"
_ = require "underscore"
express = require "express"

# Install Search API handlers to the given ExpressJS app
exports.configureApp = (app, args) ->
    # A handy way to create API reverse proxy middlewares
    # See: https://github.com/nodejitsu/node-http-proxy/issues/180#issuecomment-3677221
    # See: http://stackoverflow.com/a/21663820/390044
    url = require "url"
    httpProxy = require 'http-proxy'
    proxy = httpProxy.createProxyServer {}
    apiProxyMiddlewareFor = (path, target, rewrites) -> (req, res, next) ->
        if req.url.match path
            # rewrite pathname if any rules were specified
            if rewrites?
                newUrl = url.parse req.url
                for [pathnameRegex, replacement] in rewrites
                    newUrl.pathname = newUrl.pathname.replace pathnameRegex, replacement
                req.url = url.format newUrl
            # proxy request to the target
            proxy.web req, res,
                    target: target
                , (err, req, res) ->
                    res
                        .status 503
                        .send "Elasticsearch service unavailable\n(#{err})"
        else
            next()

    # Reverse proxy for Elasticsearch
    elasticsearchApiPath = /// ^/api/elasticsearch(|/.*)$ ///
    if process.env.ELASTICSEARCH_BASEURL?
        app.use apiProxyMiddlewareFor elasticsearchApiPath, process.env.ELASTICSEARCH_BASEURL, [
            # pathname /api/elasticsearch must be stripped for Elasticsearch
            [/// ^/api/elasticsearch ///, "/"]
        ]
    else
        app.all elasticsearchApiPath, (req, res) ->
            res
                .status 503
                .send "Elasticsearch service not configured\n($ELASTICSEARCH_BASEURL environment not set)"

exports.configureRoutes = (app, args) ->
    searchSchema =
        if process.env.DDLOG_SEARCH_SCHEMA?
            try JSON.parse fs.readFileSync process.env.DDLOG_SEARCH_SCHEMA
            catch err then console.error "Error while loading DDLOG_SEARCH_SCHEMA (#{DDLOG_SEARCH_SCHEMA}): #{err}"
    app.get "/api/search/schema.json", (req, res) ->
        res.json searchSchema

    # expose custom search result templates to frontend
    app.use "/search/template", express.static "#{process.env.DEEPDIVE_APP}/search/template"
    # fallback to default template
    app.get "/search/template/*.html", (req, res) ->
        res.redirect "/search/result-template-default.html"

