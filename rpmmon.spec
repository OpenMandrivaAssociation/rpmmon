%define name	rpmmon
%define version	0.6.3
%define release %mkrel 4

Name:		%{name}
Version:	%{version}
Release:	%{release}
Summary:	Helps you build better RPMs
License:	GPL
Group:		Development/Other
URL:		http://people.mandrakesoft.com/~gc/html/rpmmon-tut.html
Source0:	%{name}.pl
Source1:	%{name}-tut.html
Source2:	rpmmon.bash_completion
Patch:		%{name}-0.6.3.mandriva.patch
Requires:	curl
BuildArch:	noarch
Buildroot:	%{_tmppath}/%{name}-%{version}

%description
In order to produce a quality Gnu/Linux distribution based on RPM, you
need some tools which will facilitate the maintenance of the RPM
packages you are maintainer of. This is the aim of `rpmmon'.
For that purpose, the first task performed by rpmmon is to monitor what
has been announced on Freshmeat, and try to guess if the package in the
distro you're developing is older. 
Later on, this tool has grown to support additional features: 
- get the list of packages you're responsible for, either in a static
  oriented way (a local file) or more dynamically (an URL, for example
  the results of a CGI script from the QA of your distro's company)
- hence, provide an easy (e.g. command-line) interface to quickly know
  who's maintainer of a given package
- reversely, provide an easy interface to know what packages a given
  person is responsible for
- try to find automatically on Freshmeat the good project page going
  along a given RPM package
- runs rpmlint on your packages (rpmlint is a rpm correctness checker)

%prep
%setup -q -c -T -D
cp %{SOURCE0} %{name}
cp %{SOURCE1} tutorial.html
%patch

%build

%install
rm -rf %{buildroot}
install -d -m 755 %{buildroot}%{_bindir}
install -d -m 755 %{buildroot}%{_sysconfdir}/bash_completion.d
install -m 755 %{name} %{buildroot}%{_bindir}
install -m 644 %{SOURCE2} %{buildroot}%{_sysconfdir}/bash_completion.d/%{name}

%clean
rm -rf %{buildroot}

%files
%defattr(-,root,root)
%doc tutorial.html
%{_bindir}/%{name}
%config(noreplace) %{_sysconfdir}/bash_completion.d/%{name}
