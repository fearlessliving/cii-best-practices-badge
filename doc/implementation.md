# Implementation

If you just want to discuss changes to the criteria, the
first step is proposing changes to the criteria text,
whch is in the file doc/criteria.md.
But to really implement a change in the criteria, you want to
modify the implementing web application.

We have implemented a simple web application called "BadgeApp"
that quickly captures self-assertion data, evaluates criteria automatically
when it can, and provides badge information.
Our emphasis is on keeping the program relatively *simple*.

The web application is itself OSS, and
we intend for the web application to meet its own criteria.
We have implemented it with Ruby on Rails;
Rails is good for very simple web applications like this one.
We are currently using Rails version 4.2.
The production system stores the data in Postgres; in development
we use SQLite3 instead.
We deploy a test implementation to Heroku so that people can try it out
for limited testing.
The production version may also be deployed to Heroku.


## Setting up a development environment

You need to have git, Ruby (version 1.9.3 or newer), and the SQLite3 database system installed to set up a development environment.  To follow these instructions you also need rbenv (this lets you select specific versions of Ruby); rvm is an alternative not documented here.

First, use 'git' to download BadgeApp.  You can do this at the command line (assuming git is installed) with:

~~~~
git clone https://github.com/linuxfoundation/cii-best-practices-badge.git
cd cii-best-practices-badge
~~~~

For development we currently fix the version of Ruby at exactly 2.2.2.  We also need to install a number of gems (including the ones in Rails); we will install the versions specified in Gemfile.lock.  We will do completely separate per-project Gem installs, to prevent potential interference issues in the development environment.  Here's how to do that.  We presume that your current directory is the top directory of the project, aka cii-best-practices-badge.

~~~~
# Force install Ruby 2.2.2 using rbenv:
rbenv install 2.2.2
rbenv local 2.2.2 # In this directory AND BELOW, use Ruby 2.2.2 instead.

# This makes "bundle ..." use rbenv's version of Ruby:
git clone git://github.com/carsomyr/rbenv-bundler.git ~/.rbenv/plugins/bundler

gem sources --add https://rubygems.org  # Ensure you're getting gems here
gem install bundler  # Install the "bundler" gem package manager.
rbenv rehash
bundle install       # Install gems we use in Gemfile.lock, including Rails
rake db:setup        # Setup database and seed it with dummy data
~~~~

Some documents about Rails will tell you to execute "bin/rake" instead of
"rake" or to use "bundle exec ..." to execute programs.
Using rbenv-bundler (above) eliminates the need for that.

You can use "bundle outdated" to show the gems that are outdated;
be sure to test after updating any gems.


## Running locally

Once your development environment is ready, you can run the application with:

~~~~
rails s
~~~~

This will automatically set up what it needs to, and then run the
web application.
You can press control-C at any time to stop it.

Then point your web browser at "localhost:3000".


## Contributing in general

If you are contributing changes to *code*, the following rules apply.

1.  Code contributions should have a clean style.  In particular, Ruby code should be clean per Rubocop; check this using:
    rake rubocop
2.  Contributions must be secure.  At the least, ensure that there are no warnings from Brakeman (this does some static analysis for security issues):
    rake brakeman
3.  Contributions must be tested.  If you're adding new functionality, please add tests for it.  Before submitting, run the test suite to ensure check for errors:
    rake test

Please contribute in the form of a "git pull" request on the
GitHub repository if possible.

## Adding criteria

To add/modify the text of the criteria, edit these files:
doc/criteria.md
app/views/projects/_form.html.erb

If you're adding/removing fields, be sure to edit:
app/models/project.rb  # Server-side: E.g., put it the right category.
app/controllers/projects_controller.rb   # Validate permitted field.
app/assets/javascripts/project-form.js   # Client-side

When adding/removing fields, you also need to create a database migration.
The "status" (met/unmet) is the criterion name + "_status" stored as a string;
each criterion also has a name + "_justification" stored as text.
Here are the commands (assuming your current directory is at the top level,
EDIT is the name of your favorite text editor, and MIGRATION_NAME is the
logical name you're giving to the migration):

~~~~
  $ rails generate migration MIGRATION_NAME
  $ EDIT db/migrate/*MIGRATION_NAME.rb
~~~~

Your migration file should look something like this
(where add_column takes the name of the table, the name of the column,
the type of the column, and then various options):

~~~~
class MIGRATION_NAME < ActiveRecord::Migration
  def change
    add_column :projects, :crypto_alternatives_status, :string, default: '?'
    add_column :projects, :crypto_alternatives_justification, :text
  end
end
~~~~

Once you've created the migration file, you can migrate by running:

~~~~
  $ rake db:migrate
~~~~

If it fails, use the rake target db:rollback .


## App authentication via Github

The BadgeApp needs to authenticate itself through OAuth2 on Github if users are logging 
in with their Github accounts.  It also needs to authenticate itself to get repo details from Github if a 
project is being hosted there. The app needs to be registered with Github[1] and its
OAuth2 credentials stored as environment variables.  The variable names of Oauth2 credentials are 
"GITHUB_KEY" and "GITHUB_SECRET".
If running on heroku, set config variables by following instructions on [2].
If running locally, one way to start up the application is: 
GITHUB_KEY='client id' GITHUB_SECRET='client secret' rails s 
where *client id* and *client secret* are registered OAuth2 credentials of the app. The authorization callback URL in Github is: http://localhost:3000/auth/github

[1] https://github.com/settings/applications/new
[2] https://devcenter.heroku.com/articles/config-vars

## Automation

We want to automate what we can, but since automation is imperfect,
users need to be able to override the estimate.

Here's how we expect the form flow to go:

*   User clicks on "Get your badge!", request shows up at server.
*   If user isn't logged in, redirected to login (which may redirect to
    "make account").  Once logged in (including by making an account),
    continue on to...
*   "Short new project form" - show list of their github projects
    (if we can get that) that they can select, OR ask for
    project name, project URL, and repo URL.
    Once they identify the project and provide that back to us,
    we run AUTO-FILL, then use "edit project form".
*   "Edit project form" - note that flash entries will show anything
    added by auto-fill.  On "submit", it'll go to...
*   "Show project form" (a variant of the edit project, but all editable
    items cannot be selected).  Here it'll show if you got the badge,
    as well as all the details.  From "Show Project" you can:
    *   "Edit" - goes directly to edit project form
    *   "Auto" - re-run AUTO-FILL, apply the answers to anything currently
                 marked as "?", and go to edit project form.
    *   "JSON" - provide project info in JSON format.
    *   "Audit"- (Maybe) - run AUTO-FILL *without* editing the results,
                 and then show the project form with any differences
                 between auto answers and project answers as flash entries.

AUTO-FILL:
This function tries to read from the project URL and repo URLs
and determine project answers.  A few rules:

1.  Auto-fill will *ONLY* change values currently marked as "?".
2.  Anything automatically filled will be noted on the next "flash" entries
    on the edit form, so that people can check what was done (and why)
    if they want to.  Perhaps those details should be toggleable.

This does create the risk that someone can claim they earned a badge
even if they didn't.  This is the fundamental risk of self-assertion.
We could identify *differences* between automation results and the
project results - perhaps create an "audit" button on
"show project form" that provided information on differences
as flash entries on another
display of the "show project form" (that way, nothing would CHANGE).

Note: The "flash" entries for specific criteria should be shown next
to that specific criteria.  E.G., if the user asserts that their license
is "MIT" but the automation determines otherwise, then the "Audit"
report should note the difference.


## Authentication

An important issue is how to handle authentication.
Here is our current plan, which may change (suggestions welcome).

In general, we want to ensure that only trusted developer(s) of a project
can create or modify information about that project.
That means we will need to authenticate individual *users* who enter data,
and we also need to authenticate that a specific user is a trusted developer
of a particular project.

For our purposes the project's identifier is the project's main URL.
This gracefully handles project forks and
multiple projects with the same human-readable name.
We intend to prevent users from editing the project URL once
a project record has been created.
Users can always create another table entry for a different project URL,
and we can later loosen this restriction (e.g., if a user controls both the
original and new project main URL).

We plan to implement authentication in these three stages:
1.  A way for GitHub users to authenticate themselves and show that they control specific projects on GitHub.
2.  An override system so that users can report on other projects as well (this is important for debugging and error repair).
3.  A system to support users and projects not on GitHub.

For GitHub users reporting about specific projects on GitHub,
we plan to hook into GitHub itself.
We believe we can use GitHub's OAuth for user authentication.
If someone can administer a GitHub project,
then we will presume that they can report on that project.
We will probably use the &#8220;divise&#8221; module
for authentication in Rails (since it works with GitHub).

We will next implement an override system so that users can report on
other projects as well.
We will add a simple table of users and the URLs of the projects
whose data they can *also* edit (with "*" meaning "any project").
A user who can edit information for
any project would presumably also be able to modify
entries of this override table (e.g., to add other users or project values).
This will enable the Linux Foundation to easily
override data if there is a problem.
At the beginnning the users would still be GitHub users, but the project URL
they are reporting on need not be on GitHub.

Finally, we will implement a user account system.
This enables users without a GitHub user account to still use the system.
We would store passwords for each user (as iterated cryptographic hashes
with per-user salt; currently we expect to use bcrypt for iteration),
along with a user email address to eventually allow for password resets.

All users (both GitHub and non-GitHub) would have a cryptographically
random token assigned to them; a project URL page may include the
token (typically in an HTML comment) to prove that a given user is
allowed to represent that particular project.
That would enable projects to identify users who can represent them
without requiring a GitHub account.

Future versions might support sites other than GitHub; the design should
make it easy to add other sites in the future.

We intend to make public the *username* of who last
entered data for each project (generally that would be the GitHub username),
along with the edit time.
The data about the project itself will also be public, as well
as its badge status.

In the longer term we may need to support transition of a project
from one URL to another, but since we expect problems
to be relatively uncommon, there is no need for that capability initially.

## Who can edit project P?

(This is a summary of the previous section.)

A user can edit project P if one of the following is true:

1.  If the user has "superuser" permission then the user can edit the badge information about any project.  This will let the Linux Foundation fix problems.
2.  If project P is on GitHub AND the user is authorized via GitHub to edit project P, then that user can edit the badge information about project P.  In the future we might add repos other than GitHub, with the same kind of rule.
3.  If the user's cryptographically randomly assigned "project edit validation code" is on the project's main web site (typically in an HTML comment), then the user can edit the badge information about project P.  Note that if the user is a local account (not GitHub), then the user also has to have their email address validated first.

## Filling in the form

Previously we hoped to auto-generate the form, but it's difficult to create a good UI experience that way.  So for the moment, we're not doing that.

## GitHub-related badges

Pages related to GitHub-related badges include:

*   http://shields.io/ - serves files that display a badge (as good-looking scalable SVG files)
*   https://github.com/badges/shields -  Shields badge specification, website and default API server (connected to shields.io)
*   http://nicbell.net/blog/github-flair - a blog post that identifies and discusses popular GitHub flair (badges)

We want GitHub users to think of this
as &#8220;just another badge to get.&#8221;

We intend to sign up for a few badges so we can
evalute their onboarding process,
e.g., Travis (CI automation), Code Climate (code quality checker including
BrakeMan), Coveralls (code coverage), Hound (code style),
Gymnasium (checks dependencies), HCI (looks at your documentation).
For example, they provide the markdown necessary to embed the badge.
See ActiveAdmin for an example, take a few screenshots.
Many of these badges try to represent real-time status.
We might not include these badges in our system, but they
provide useful examples.

## Other badging systems

Mozilla's Open Badges project at <http://openbadges.org/>
is interesting, however, it is focused on giving badges to
individuals not projects.

## License detection

Some information on how to detect licenses can be found in
[&#8220;Open Source Licensing by the Numbers&#8221; by Ben Balter](https://speakerdeck.com/benbalter/open-source-licensing-by-the-numbers).

## Analysis

We intend to use the OWASP ZAP web application scanner to find potential
vulnerabilities before full release.
This lets us fulfill the "dynamic analysis" criterion.


# See also

See the separate "[background](./background.md)" and
"[criteria](./criteria.md)" pages for more information.
