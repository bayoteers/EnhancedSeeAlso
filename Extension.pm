# -*- Mode: perl; indent-tabs-mode: nil -*-
#
# The contents of this file are subject to the Mozilla Public
# License Version 1.1 (the "License"); you may not use this file
# except in compliance with the License. You may obtain a copy of
# the License at http://www.mozilla.org/MPL/
#
# Software distributed under the License is distributed on an "AS
# IS" basis, WITHOUT WARRANTY OF ANY KIND, either express or
# implied. See the License for the specific language governing
# rights and limitations under the License.
#
# The Original Code is the SeeAlso Bugzilla Extension.
#
# The Initial Developer of the Original Code is Stephen Jayna
# Portions created by the Initial Developer are Copyright (C) 2011 the
# Initial Developer. All Rights Reserved.
#
# Contributor(s):
#   ext-stephen.jayna@nokia.com

package Bugzilla::Extension::SeeAlso;
use strict;
use base qw(Bugzilla::Extension);
use Data::Dumper;

# This code for this is in ./extensions/SeeAlso/lib/Util.pm
use Bugzilla::Extension::SeeAlso::Util;

our $VERSION = '0.01';

sub config {
    my ($self, $args) = @_;

    my $config = $args->{config};
    $config->{SeeAlso} = "Bugzilla::Extension::SeeAlso::ConfigSeeAlso";
}

sub config_add_panels {
    my ($self, $args) = @_;

    my $modules = $args->{panel_modules};
    $modules->{SeeAlso} = "Bugzilla::Extension::SeeAlso::ConfigSeeAlso";
}

# See the documentation of Bugzilla::Hook ("perldoc Bugzilla::Hook"
# in the bugzilla directory) for a list of all available hooks.
sub install_update_db {
    my ($self, $args) = @_;

}

sub template_before_process {
    my ($self, $args) = @_;

    my $cgi = Bugzilla->cgi;

    my $vars = $args->{vars};
    my $file = $args->{file};

    $args->{bug} = $cgi->param('id');

    if ($file eq 'bug/edit.html.tmpl') {
        _display_external_bug_summary($self, $args);
    }
}

sub _display_external_bug_summary($$) {
    my ($self, $args) = @_;

    my $cgi = Bugzilla->cgi;

    # If a bug is registered in the See Also then show details of that external
    # bug in the See Also area.

    my $bug_id = $args->{'bug'};

    my $bug = new Bugzilla::Bug($bug_id);

    my $format = $args->{'format'};
    my $vars   = $args->{'vars'};

    if (!$cgi->param('ctype') || $cgi->param('ctype') eq 'html') {
        my @external_bugs;

        my %whitelisted_regexps;

        foreach (split(/\n/, Bugzilla->params->{'external_bug_whitelisted_urls'})) {
            my ($external_name, $external_regexp) = split(/=/, $_);
            if (length $external_name > 1) {
                $whitelisted_regexps{$external_name} = $external_regexp;
            }
        }

        my %external_bugzilla_login;
        my %external_bugzilla_httpauth;

        foreach (split(/\n/, Bugzilla->params->{'external_bug_bugzilla_credentials'})) {
            my ($external_name, $external_credentials) = split(/=/, $_);
            if ($whitelisted_regexps{$external_name} || keys %whitelisted_regexps == 0) {
                my ($first, $second, $third, $fourth) = split(/,/, $external_credentials);
                if (!$third) {
                    $external_bugzilla_login{$external_name}->{'login'}    = $first;
                    $external_bugzilla_login{$external_name}->{'password'} = $second;
                }
                else {
                    $external_bugzilla_httpauth{$external_name}->{'server'}   = $first;
                    $external_bugzilla_httpauth{$external_name}->{'realm'}    = $second;
                    $external_bugzilla_httpauth{$external_name}->{'login'}    = $third;
                    $external_bugzilla_httpauth{$external_name}->{'password'} = $fourth;
                }
            }
        }

        my %external_bugzilla_fields;
        foreach (split(/\n/, Bugzilla->params->{'external_bug_fields'})) {
            my ($external_name, $external_fields) = split(/=/, $_);

            $external_bugzilla_fields{$external_name} = $external_fields;
        }

        foreach my $url (@{ $bug->see_also }) {
            my $valid_name;

            if (keys %whitelisted_regexps > 0) {
                while (my ($external_name, $valid_url) = each(%whitelisted_regexps)) {
                    if ($url =~ m/$valid_url/i) {
                        $valid_name = $external_name;
                    }
                }
            }

            if (!$valid_name) {
                $valid_name = 'default';
            }

            my $browser = LWP::UserAgent->new();
            my %post_fields;

            $browser->protocols_allowed([ 'http', 'https' ]);

            # Get the proxy defined in Bugzilla, stripping and trailing slash.
            my $proxy = Bugzilla->params->{'proxy_url'};
            $proxy =~ s/\/$//gis;

            # Setting this ensure's that Crypt:SSLeay's built-in proxy support is used.
            $ENV{HTTPS_PROXY} = $proxy;

            # If the URL of the proxy is given, use it, else get this information
            # from the environment variable.
            my $proxy_url = Bugzilla->params->{'proxy_url'};
            if ($proxy_url) {
                $browser->proxy(['http'], $proxy_url);
            }

            $browser->cookie_jar({});
            $browser->timeout(10);

            # Use http-auth login or bugzilla login or no login depending on params
            if ($external_bugzilla_httpauth{$valid_name}) {
                $browser->credentials($external_bugzilla_httpauth{$valid_name}->{'server'},
                                      $external_bugzilla_httpauth{$valid_name}->{'realm'},
                                      $external_bugzilla_httpauth{$valid_name}->{'login'} => $external_bugzilla_httpauth{$valid_name}->{'password'});
            }
            elsif ($external_bugzilla_login{$valid_name}) {
                $post_fields{'Bugzilla_login'}    = $external_bugzilla_login{$valid_name}->{'login'};
                $post_fields{'Bugzilla_password'} = $external_bugzilla_login{$valid_name}->{'password'};
            }
            $post_fields{'ctype'} = 'xml';
            my $response = $browser->post($url, \%post_fields);

            if ($response->is_success) {
                if ($response->content =~ m/\<bug error="NotPermitted"\>/) {
                    push @external_bugs, { 'Error' => 'login_err' };
                }
                else {
                    my @external_fields = split(',', $external_bugzilla_fields{$valid_name});

                    my @to_template;

                    my $content = $response->content;

                    # Get XML fields from external bugzilla
                    foreach my $external_field (@external_fields) {
                        my ($external_field, $local_field) = split(/:/, $external_field);
                        my ($match) = $content =~ /<$external_field>(.*?)<\/$external_field>/ig;

                        if ($match) {
                            push @to_template, { 'field' => $local_field, 'value' => $match };
                        }
                        else {
                            push @to_template, { 'field' => $local_field, 'value' => '&nbsp;' };
                        }
                    }
                    push @external_bugs, \@to_template;
                }
            }
            else {
                push @external_bugs, { 'Error' => 'http_error' };
            }
        }
        $vars->{'external_bugs'} = \@external_bugs;
    }
}

__PACKAGE__->NAME;
