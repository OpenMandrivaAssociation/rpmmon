Name:		rpmmon
Version:	0.6.3
Release:	10
Summary:	Helps you build better RPMs
License:	GPL
Group:		Development/Other
URL:		https://www.zarb.org/~gc/html/rpmmon-tut.html
Source0:	%{name}.pl
Source1:	%{name}-tut.html
Source2:	rpmmon.bash_completion
Patch0:		%{name}-0.6.3.mandriva.patch
Patch1:		rpmmon-0.6.3-maintdb.patch
Patch2:		rpmmon-0.6.3-curl-ssl.patch
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
%patch0
%patch1 -p1 -b .maintdb
%patch2 -p0

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


%changelog
* Tue Sep 15 2009 Thierry Vignaud <tvignaud@mandriva.com> 0.6.3-9mdv2010.0
+ Revision: 442760
- rebuild

* Sat Jan 03 2009 Tomasz Pawel Gajc <tpg@mandriva.org> 0.6.3-8mdv2009.1
+ Revision: 323623
- Patch2: fix checks for SSL support in curl (check for enabled features like SSL which could be provided by gnutls or openssl libraries)

* Wed Jul 23 2008 Thierry Vignaud <tvignaud@mandriva.com> 0.6.3-7mdv2009.0
+ Revision: 242563
- rebuild
- kill re-definition of %%buildroot on Pixel's request

  + Nicolas Vigier <nvigier@mandriva.com>
    - update URL

  + Olivier Blin <oblin@mandriva.com>
    - restore BuildRoot

* Wed Jul 25 2007 Olivier Blin <oblin@mandriva.com> 0.6.3-5mdv2008.0
+ Revision: 55302
- use new maintainers database
- bunzip sources
- Import rpmmon



* Tue Aug 01 2006 Guillaume Rousse <guillomovitch@mandriva.org> 0.6.3-4mdv2007.0
- %%mkrel

* Thu Jul 28 2005 Guillaume Rousse <guillomovitch@mandriva.org> 0.6.3-3mdk 
- spec cleanup
- fix mandriva URLs

* Thu Jul 22 2004 Guillaume Rousse <guillomovitch@mandrake.org> 0.6.3-2mdk 
- noraple option for bash-completion file

* Thu Dec 11 2003 Guillaume Cottenceau <gc@mandrakesoft.com> 0.6.3-1mdk
- new version

* Mon Aug 25 2003 Guillaume Rousse <guillomovitch@linux-mandrake.com> 0.6.0-2mdk
- requires curl (fix bug #4228)

* Fri May 16 2003 Guillaume Cottenceau <gc@mandrakesoft.com> 0.6.0-1mdk
- new version for lord grousse

* Sat Jan 04 2003 Guillaume Rousse <g.rousse@linux-mandrake.com> 0.5-0.beta.2mdk
- rebuild

* Wed Sep 04 2002 Guillaume Rousse <g.rousse@linux-mandrake.com> 0.5-0.beta.1mdk
- first mdk release :-)
- bash completion
