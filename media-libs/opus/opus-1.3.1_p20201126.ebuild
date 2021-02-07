# Copyright 1999-2021 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

inherit flag-o-matic multilib-minimal autotools

case ${PV} in
	9999)
		inherit git-r3
		KEYWORDS=""
		EGIT_REPO_URI="https://gitlab.xiph.org/xiph/opus.git"
		;;
	*_p*)
		KEYWORDS="~alpha ~amd64 ~arm ~arm64 ~hppa ~ia64 ~mips ~ppc ~ppc64 ~sparc ~x86"
		MY_COMMIT="d633f523e36e3b6d01cc6d57386458d770d618be"
		SRC_URI="https://gitlab.xiph.org/xiph/opus/-/archive/${MY_COMMIT}/opus-${MY_COMMIT}.tar.gz -> ${P}.tar.gz"
		S="${WORKDIR}/${PN}-${MY_COMMIT}"
		;;
	*)
		KEYWORDS="~alpha ~amd64 ~arm ~arm64 ~hppa ~ia64 ~mips ~ppc ~ppc64 ~sparc ~x86"
		SRC_URI="https://archive.mozilla.org/pub/opus/${P}.tar.gz"
		;;
esac

DESCRIPTION="Open codec for interactive speech and music transmission over the Internet"
HOMEPAGE="https://opus-codec.org/"

LICENSE="BSD"
SLOT="0"
INTRINSIC_FLAGS="cpu_flags_x86_sse cpu_flags_arm_neon"
IUSE="custom-modes doc static-libs ${INTRINSIC_FLAGS}"

BDEPEND="doc? (
		app-doc/doxygen
		media-gfx/graphviz
	)"

src_prepare() {
	default
	eautoreconf
}

multilib_src_configure() {
	local myeconfargs=(
		$(use_enable custom-modes)
		$(use_enable doc)
		$(use_enable static-libs static)
	)
	for i in ${INTRINSIC_FLAGS} ; do
		use ${i} && myeconfargs+=( --enable-intrinsics )
	done
	if is-flagq -ffast-math || is-flagq -Ofast; then
		myeconfargs+=( "--enable-float-approx" )
	fi

	ECONF_SOURCE="${S}" econf "${myeconfargs[@]}"
}

multilib_src_install_all() {
	default
	find "${ED}" -name "*.la" -delete || die
}
