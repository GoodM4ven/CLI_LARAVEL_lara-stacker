<div align="center">
    بسم الله الرحمن الرحيم
</div>


## Introduction

Laravel Sail's [DevContainer](https://laravel.com/docs/sail#using-devcontainers) setup is great, except when it **relies on VSC and some weird extensions to keep up with; let alone Docker not outsmarting everybody!** Meanwhile, I might as well just do my [TALL stack](https://tallstack.dev/) development <u>***locally***</u>...

With this setup, one doesn't have to worry about the things I've mentioned, in addition to gaining the following advantages too:

- Performance boost on potatops.
- Running multiple sites at the same time and developing simultaneously, which is crazy creative when it comes to simple ideas here and there!
- Customizations such as SSL and 3rd party tools integration is way easier if you deal with it locally; and doesn't necessarily mean that you'd have a messy setup if every operation is **managed through an organized script**.
- Packages, and [native](https://nativephp.com) apps development soon enough, are just natural when having most of the tools installed out of boxes!

And, yes, these are valid reasons considering that Laravel itself created [Herd](https://herd.laravel.com) AFTER I started this pro- *kidding, but for the record, I was actually first*- just to offer this sort of setup on MacOS of all things! And then they ported it to bloody Windows. And when they're asked about Linux, they raised a huge middle f-lag. `(╬ Ò﹏Ó)`

### Tech Stack List

- Packages
  - Active
    - [git](https://github.com/git/git)
    - [gt](https://graphite.dev/) [@withgraphite/graphite-cli@stable]
    - [curl](https://github.com/curl/curl)
    - **[php](https://www.php.net/)**
    - [npm](https://nodejs.org/) (Until all package migrates away!)
    - **[bun](https://bun.sh)** (Opinionated)
    - **[composer](https://getcomposer.org/)**
    - [mkcert](https://github.com/FiloSottile/mkcert) (Requires `mkcert -install` to be ran manually **once** after the setup script)
    - [expose](https://expose.dev/docs) (Installed if `EXPOSE_TOKEN` is provided in [`.env`] file. Use `expose share https://[site-name].test` to work properly)
  - Passive
    - [libnss3-tools](https://packages.ubuntu.com/focal/libnss3-tools)
    - [ghostscript](https://ghostscript.readthedocs.io)
    - [ffmpeg](https://github.com/FFmpeg/FFmpeg)
    - [php-curl](https://www.php.net/manual/en/book.curl.php)
    - [php-xml](https://www.php.net/manual/en/refs.xml.php)
    - [php-dom](https://www.php.net/manual/en/book.dom.php)
    - [php-bcmath](https://www.php.net/manual/en/book.bc.php)
    - [php-zip](https://www.php.net/manual/en/book.zip.php)
    - [php-imagick](https://www.php.net/manual/en/book.imagick.php)
    - [php-gd](https://www.php.net/manual/en/book.image.php)
    - [php-xdebug](https://xdebug.org/)
    - [php-mysql](https://www.php.net/manual/en/book.mysql.php)
    - [php-sqlite3](https://www.php.net/manual/en/book.sqlite3.php)
    - [php-redis](https://github.com/phpredis/phpredis)
    - [firacode](https://github.com/tonsky/FiraCode)

- Services
  - [apache2](https://httpd.apache.org/)
  - [sqlite3](https://www.sqlite.org/index.html)
  - [mysql-server](https://www.mysql.com/) (port 3306)
  - [redis](https://redis.io/) (port 6379)
  - [mailpit](https://github.com/axllent/mailpit) (http://localhost:8025)
  - [minio](https://min.io/) (http://localhost:9000)

- Applications
  - [google-chrome-stable](https://www.google.com/chrome/) (Required for Laravel Dusk, sadly!)


## Installation

- Either download the project zipped, or `git clone` it.

- Extract the scripter somewhere and navigate into it:
  ```bash
  cd ~/Downloads && unzip ./lara-stacker-x.x.x.zip -d ./ && cd lara-stacker-x.x.x
  ```

- Create a [[`.env`](./.env)] file from the [[`.env.example`](./.env.example)] one and fill in its content; replacing the `<placeholders>`.
  ```bash
  cp .env.example .env && nano .env
  ```

- Run the script with super-user permissions:
  ```bash
  chmod +x ./lara-stacker.sh && sudo ./lara-stacker.sh
  ```

- Choose to [**setup**](./scripts/setup.sh) your Ubuntu environment first, which will install everything necessary for local Laravel development, and eventually create a [`done-setup.flag`] file in the directory.

- Then choose to either:
  - Create a [**TALL**](./scripts/TALL/create.sh) project through its management section, then continue onwards with the installed [TALL-Stacker](https://github.com/GoodM4ven/PACKAGE_LARAVEL_tall-stacker) package via its Artisan command (soon™).
  - Or just create a [**raw**](./scripts/create_raw.sh) Laravel one, instead.
  - You can also [**import**](./scripts/TALL/import.sh) an already existing project into the same TALL setup.

That's it. You'll have your first project accessible in the end (displaying the site's URL too). And just praise Allah instead of wasting the waiting time! `:)`

> [!NOTE]
> If you want to debug the process or display all output during the scripts, change the `LOGGING_LEVEL` variable in your [[`.env`](./.env)] file.


## Notes

### Opinionated Modifications

- `curl -fsSL https://bun.sh/install | bash`
- `bun add -g @withgraphite/graphite-cli@stable`
- `ln -s $projects_directory/` (Creating a shortcut for [`/var/www/html`] directory in a [`~/Code`] directory)
- `sudo mkdir $projects_directory/.packages` (Creating a [`/var/www/html/.packages`] directory)
- `sudo cp $lara_stacker_dir/files/.opinionated/project.code-workspace ./$escaped_project_name.code-workspace` (Creating VSC workspaces on Desktop)
- `sudo cp $lara_stacker_dir/files/.opinionated/.prettierrc ./.prettierrc` (Adding Prettier config [files](./files/.opinionated/.prettierrc) to projects)
- Adding Bash aliases to the user's [`~/.bashrc`] file:
  ```bash
  echo -e "\n# Laravel Aliases\nalias cda='composer dump-autoload'\nalias art='php artisan'\nalias wipe='php artisan db:wipe'\nalias fresh='php artisan migrate:fresh'\nalias mfs='php artisan migrate:fresh --seed'\nalias opt='php artisan optimize:clear'\nalias dev='bun run dev'\n" >>/home/$USERNAME/.bashrc
  ```

### Before Production

- If you had provided an Expose token, remove the project [bootstrap/app.php]'s middleware `trust` configuration.


## Development

There is [another package](https://github.com/VPremiss/TALL-Stacker) on the way to complement tall-stack packages installation; soon, (in sha' allah)...

### Changelogs

You can check out the package's [changelogs](https://app.whatthediff.ai/changelog/github/GoodM4ven/lara-stacker) online via WTD.

### Progress

You can also checkout the project's roadmap from [here](https://github.com/users/GoodM4ven/projects/2/views/1).


## Support

Support ongoing package maintenance as well as the development of **other projects** through [sponsorship](https://github.com/sponsors/GoodM4ven) or one-time [donations](https://github.com/sponsors/GoodM4ven?frequency=one-time&sponsor=GoodM4ven) if you prefer.

And may Allah accept your strive; aameen.

### License

This package is open-sourced software licensed under the [MIT license](LICENSE.md).

### Credits

- [ChatGPT](https://chat.openai.com)
- [Graphite](https://graphite.dev)
- [Laravel](https://github.com/Laravel)
- [Spatie](https://github.com/spatie)
- [BeyondCode](https://beyondco.de)
- [The Contributors](../../contributors)
- All the [technologies](#tech-stack-list) used to set up this whole development environment...
- And the generous individuals that we've learned from and been supported by throughout our journey...


<div align="center">
   <br>والحمد لله رب العالمين
</div>
