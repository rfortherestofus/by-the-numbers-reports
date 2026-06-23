# Template Project

This repo is designed to be used as a template for most (all?) projects. 
Keep the content of this README at the bottom of your project README so that the intended purpose of the repo structure can be looked up later too.

## Repo structure

- `.github/workflows/`: Place where GH actions live. Currently only contains `publish.yml` that can deploy to Cloudflare using GH Actions. See also ["CICD for publishing websites"](#cicd-for-publishing-websites).

- `data_clean/`: Directory for clean or mostly clean datasets. When we will manage data across multiple years or when we have to do lots of processing, interconnected datasets, think about using a Neon Postgres database instead.

- `data_raw/`: Put in files that are not cleaned yet. 
Most useful when client delivers lots of small files.

- `outputs/`: This is where you can have your code put in files like PDFs. 
All content within this directory is inside of `.gitignore`. 
So you can use it for local testing. 
For sharing data we want to have a dedicated Cloudflare R2 bucket.

- `R/`: This directory contains all R code. 
It doesn't need to contain solely `.R` files. 
It can also contain subdirectories (unlike in an R package where the `R/` directory can only have `.R` files.)

- `website/`: This directory is filled with a Quarto website template. 
Use this directory for occasions where we want to publish a website for the client.
The rendered content of this website, i.e. the `_site/` directory is inside of `.gitignore`.
This avoids flooding the commits with auto-generated files.
For publishing the website see section ["CICD for publishing websites"](#cicd-for-publishing-websites)


## CICD for publishing websites

>[!IMPORTANT]
> If you want to deploy a website you will need to manually create the `published` branch from the `main` branch.
> Also, the following repo secrets need to be set:
>
> - `CLOUDFLARE_API_TOKEN`: Token with permissions for interacting with workers. Easiest approach: Use the "Edit Cloudflare Workers" template inside of Profile > API tokens
> - `CLOUDFLARE_ACCOUNT_ID`: Account ID inside of CF
> - `ORG_ADMIN_TOKEN`: GH PAT with write permissions

The deployed content of the `website/` directory lives inside the `published` branch.
This branch can only be updated by making a PR from `main` to `published`.
When that PR is approved and the `main` branch is merged, then a GH Actions pipeline will render the Quarto files within the `website/` directory and force-push the created `_site` to that branch.
Also, the content from that directory will be deployed to Cloudflare using the specifications from `wrangler.toml`.

This setup gives us the following advantages:

- The deployed website cannot be overwritten by accident as it needs a deliberate PR from `main` to `published`
- The rendered content, i.e. all the files that Quarto generates, can be in `.gitignore` and doesn't bloat regular commits. 
Instead the content just lives within the `published` branch.

