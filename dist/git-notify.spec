%global commit 8312226426d37999601c17bdb995558acb9fafca
%global shortcommit %(c=%{commit}; echo ${c:0:7})

Name:           git-notify
Version:        0^20210617.%{shortcommit}
Release:        1%{?dist}
Summary:        Git commit alerts

License:        -
URL:            https://github.com/losuler/%{name}
Source0:        https://github.com/losuler/%{name}/archive/%{commit}.tar.gz

Requires:       bash
Requires:       procps-ng
Requires:       coreutils
Requires:       grep
Requires:       sed
Requires:       git
Requires:       util-linux
Requires:       curl

Recommends:     libnotify
BuildArch:      noarch

%description
A small bash script to watch a git repo and send alerts of any new commits.

%prep
%autosetup -n %{name}-%{commit}

%build
# Not required.

%install
mkdir -p %{buildroot}/%{_bindir}
mkdir -p %{buildroot}/%{_sysconfdir}
mkdir -p %{buildroot}/%{_userunitdir}
install -m 0755 %{name}.sh %{buildroot}/%{_bindir}/%{name}
install -m 0644 %{name}.conf %{buildroot}/%{_sysconfdir}/
install -m 0644 dist/%{name}.service %{buildroot}/%{_userunitdir}/

%files
%doc README.md CONTRIBUTORS.md
%{_bindir}/%{name}
%config %{_sysconfdir}/%{name}.conf
%{_userunitdir}/%{name}.service

%changelog
* Fri Sep 17 2021 losuler <losuler@posteo.net> - 0^20210917.8312226-1
- Initial release.
