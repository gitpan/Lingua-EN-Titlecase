use inc::Module::Install;

name            "Lingua-EN-Titlecase";
all_from        "lib/Lingua/EN/Titlecase.pm";

perl_version '5.006'; # for POSIX classes

requires  "parent"                => "0.2";
requires  "Class::Accessor::Fast" => 0;
requires  "Carp"                  => 0;
requires  "List::Util"            => 0;

build_requires  "Test::More" => 0;

auto_install;
WriteAll;

__END__
