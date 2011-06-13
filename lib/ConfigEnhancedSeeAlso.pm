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
# The Original Code is the Bugzilla Example Plugin.
#
# The Initial Developer of the Original Code is Canonical Ltd.
# Portions created by Canonical Ltd. are Copyright (C) 2008
# Canonical Ltd. All Rights Reserved.
#
# Contributor(s): Max Kanat-Alexander <mkanat@bugzilla.org>
#                 Bradley Baetz <bbaetz@acm.org>

package Bugzilla::Extension::EnhancedSeeAlso::ConfigEnhancedSeeAlso;
use strict;
use warnings;

use Data::Dumper;

use Bugzilla::Config::Common;

sub get_param_list {
    my ($class) = @_;

    my @param_list = (
                      {
                         name    => 'external_bug_blacklisted_urls',
                         desc    => 'Regexp for illegal urls in See Also -field.',
                         type    => 't',
                         default => '',
                      },
                      {
                         name    => 'external_bug_whitelisted_urls',
                         desc    => 'Names and regexps for the servers to be used in external bug display.',
                         type    => 'l',
                         default => '',
                      },
                      {
                         name    => 'external_bug_bugzilla_credentials',
                         desc    => 'Bugzilla login credentials for each external server used.',
                         type    => 'l',
                         default => '',
                      },
                      {
                         name    => 'external_bug_fields',
                         desc    => 'Fields to fetch from the external server and to which names they are mapped.',
                         type    => 'l',
                         default => '',
                      },
                     );

    return @param_list;
}

1;
