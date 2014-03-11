Strider Cookbook
================

[![Build Status](https://travis-ci.org/jagoda/chef-strider.png?branch=master)](https://travis-ci.org/jagoda/chef-strider)

Installs the [Strider CD][strider] server.

## Requirements

### Platform

 + Tested on Ubuntu 12.04

### Cookbooks

 + [git](https://github.com/mdxp/nodejs-cookbook)
 + [nodejs](https://github.com/mdxp/nodejs-cookbook)

## Attributes

 + node[:strider][:directory] - The directory to install `strider` to. Defaults
    to `/opt/strider`.
 + node[:strider][:log] - The path to the strider log file. Defaults to
    `/var/log/strider.log`.
 + node[:strider][:user] - The name of the user to run the server as. Defaults
    to 'strider'.
 + node[:strider][:group] - The name of the group that owns strider resources.
    Defaults to 'strider'.
 + node[:strider][:port] - The port that `strider` should listen on. If not
    provider, `strider` defaults to 3000.
 + node[:strider][:database_url] - The URL for the mongodb to use. Defaults to
    localhost.
 + node[:strider][:github][:client_id] - The GitHub client ID that strider
    should use.
 + node[:strider][:github][:client_secret] - The GitHub client secret that
    strider should use.
 + node[:strider][:bitbucket][:client_id] - The Bitbucket client ID that strider
    should use.
 + node[:strider][:bitbucket][:client_secret] - The Bitbucket client secret that
    strider should use.
 + node[:strider][:bitbucket][:host] - The Bitbucket server that strider should
    use.
 + node[:strider][:url] - The URL that strider should advertise as it's base
    URL. If not specified, strider defaults to `http://localhost:3000`.
 + node[:strider][:data] - The directory that strider should use for job data.
    If not specified, `node[:strider][:directory]/data` is used.
 + node[:strider][:plugins] - A single git URL or list of git URLs that point to
    additional strider plugins that should be installed.

## Usage

    include_recipe "strider"

[strider]: "https://github.com/Strider-CD/strider" "Strider"
