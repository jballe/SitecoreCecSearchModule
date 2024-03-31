# SitecoreCecSearchModel - Powershell module for Sitecore Search

This module lets you interact with the APIs provided by the Sitecore Customer Engagement Console (CEC) for Sitecore Search.

> This module is using unofficial APIs and is completely unsupported by Sitecore or anyone else. Use it at your own risk!
>
>The API requests have been deducted from using the [Sitecore Customer Engagement Console (CEC)](https://cec.sitecorecloud.io) and there is of course a risk that those requests/unofficial APIs might change any day.

The purpose of this module is to

* keep a log of Sitecore Search configuration in git
* allow easier investigation and comparison of configuration
* help simulate environments in a single Search account with environment specific connectors.

## Installation

Module is available in [Powershell Gallery](https://www.powershellgallery.com/packages/SitecoreCecSearchModule/)

## Authentication

When using username and password for CEC, you can use the same here:

```powershell
Invoke-CecLogin -Email $Email -Password $Password
```

When using Single-Sign-On, it is a bit more complicated. When authenticated you can identify the Bearer token and assign it directly

```powershell
Set-CecAccessToken $BearerTokenValueWithoutBearerPrefix
```

## Actions

There are sample script in the [src/scripts folder](./src/scripts) with some of the actions.
