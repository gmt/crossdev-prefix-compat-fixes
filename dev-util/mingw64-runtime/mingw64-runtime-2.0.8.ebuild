# Copyright 1999-2013 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/dev-util/mingw64-runtime/mingw64-runtime-2.0.7.ebuild,v 1.1 2013/02/18 19:52:50 vapier Exp $

EAPI=5

export CBUILD=${CBUILD:-${CHOST}}
export CTARGET=${CTARGET:-${CHOST}}
if [[ ${CTARGET} == ${CHOST} ]] ; then
	if [[ ${CATEGORY/cross-} != ${CATEGORY} ]] ; then
		export CTARGET=${CATEGORY/cross-}
	fi
fi

inherit flag-o-matic eutils multilib autotools

DESCRIPTION="Free Win64 runtime and import library definitions"
HOMEPAGE="http://mingw-w64.sourceforge.net/"
SRC_URI="mirror://sourceforge/mingw-w64/mingw-w64-v${PV}.tar.gz"

LICENSE="BSD"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE="crosscompile_opts_headers-only doc"
RESTRICT="strip"

S=${WORKDIR}/mingw-w64-v${PV}

is_crosscompile() {
	[[ ${CHOST} != ${CTARGET} ]]
}
just_headers() {
	use crosscompile_opts_headers-only && [[ ${CHOST} != ${CTARGET} ]]
}

src_pretend() {
	if [[ ${CBUILD} == ${CHOST} && ${CHOST} == ${CTARGET} ]] ; then
		die "pure-native build not supported."
	fi
	local abi target targetvar
	for abi in $(get_install_abis) ; do
		targetvar="CTARGET_${abi}"
		target="${!targetvar}"
		if [[ ${target} != x86_64-* && ${target} != i[3456]86-* ]] ; then
			die "unsupported target: ${target}"
		fi
		if [[ ${target} != *-w64-mingw32 ]] ; then
			die "unsupported target: ${target}"
		fi
	done
}

src_unpack() {
	unpack ${A}
	find "${WORKDIR}" -type f -exec touch -r . {} +
}

src_prepare() {
	epatch "${FILESDIR}"/mingw64-runtime-2.0.8-usr_include.patch
	eautoreconf
}

src_configure() {
	mkdir -p "${WORKDIR}"/build/mingw-w64-headers
	mkdir -p "${WORKDIR}"/build/mingw-w64-crt
	mkdir -p "${WORKDIR}"/sysroot

	pushd "${WORKDIR}"/build/mingw-w64-headers > /dev/null
	ECONF_SOURCE="${S}"/mingw-w64-headers CHOST=${CTARGET} econf \
		--enable-sdk \
		--prefix="/usr"
	popd > /dev/null
}

src_compile() {
	# install the local headers as the crt step wants latest
	pushd "${WORKDIR}"/build/mingw-w64-headers > /dev/null
	emake

	just_headers && { popd >/dev/null ; return 0 ; }

	einfo "pre-installing headers to ${WORKDIR}/sysroot"
	emake install DESTDIR="${WORKDIR}/sysroot"
	popd >/dev/null


	pushd "${WORKDIR}"/build/mingw-w64-crt > /dev/null
	local myconf=""
	local abi target targetvar
	for abi in $(get_install_abis) ; do
		targetvar="CTARGET_${abi}"
		target="${!targetvar}"
		case ${target} in
			x86_64-*) myconf="${myconf} --enable-lib32" ;;
			i[3-6]86-*) myconf="${myconf} --enable-lib64" ;;
		esac
		einfo "enabling abi ${abi}"
	done

	einfo "configuring crt library to use preinstalled headers"
	CHOST=${CTARGET} strip-unsupported-flags
	ECONF_SOURCE="${S}"/mingw-w64-crt CHOST=${CTARGET} econf \
		"${myconf}"
        --prefix="/usr"
		--with-sysroot="/usr"
	emake
	popd > /dev/null
}

src_install() {
	pushd "${WORKDIR}"/build/mingw-w64-headers > /dev/null
	emake install DESTDIR="${ED}"
	popd > /dev/null

	# insinto "/usr/${CTARGET}"
	if is_crosscompile ; then
		# gcc is configured to look at specific hard-coded paths for mingw #419601
		dosym usr "/usr/${CTARGET}"/mingw
		dosym usr "/usr/${CTARGET}/${CTARGET}"
		dosym usr/include "/usr/${CTARGET}"/sys-include
	fi

	just_headers && return 0

	pushd "${WORKDIR}"/build/mingw-w64-crt > /dev/null
	# somehow (but how!?) mingw-w64-crt appends $EPREFIX
	emake install DESTDIR="${D}" 
	env -uRESTRICT CHOST="${CTARGET}" prepallstrip
	use doc || rm -rf "${ED}"/usr/doc
	popd > /dev/null
}
