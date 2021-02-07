# Copyright 1999-2021 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

PLOCALES="de_DE es_ES fr_FR it_IT nl_NL pl_PL pt_BR pt_PT sk_SK sv_SE"
PLOCALE_BACKUP="en"
inherit qmake-utils l10n readme.gentoo-r1

DESCRIPTION="Internet Jam Session Software"
HOMEPAGE="https://jamulus.io/"
MY_PV="r$(ver_rs 1-2 _)"
MY_PN="${PN^j}"
SRC_URI="https://github.com/${PN}software/${PN}/archive/${MY_PV}.tar.gz -> ${P}.tar.gz"

# Jamulus: GPL-2
# Icons:
# https://openclipart.org pixmaps: public-domain
# http://famfamfam.com by Mark James; country flags: CC-BY-2.5
LICENSE="GPL-2 public-domain CC-BY-2.5"
SLOT="0"
KEYWORDS="~amd64"
IUSE="server +client jack"

REQUIRED_USE="
	|| ( server client )
	client? ( jack )
"

# jack2 is explicitly listed in the upstream dependency section,
# however the linux install scripts also reference jack1, so
# it does not matter
RDEPEND="
	dev-qt/qtcore:5
	dev-qt/qtdeclarative:5
	dev-qt/qtconcurrent:5
	dev-qt/qtxml:5
	dev-qt/qtnetwork:5
	client? ( dev-qt/qtgui:5 dev-qt/qtwidgets:5 )
	jack? ( virtual/jack )
	>=media-libs/opus-1.3.1_p20201126[custom-modes]
	"

DEPEND="${RDEPEND}"

# Do not reinvent the wheel
BDEPEND="
	>=app-text/xmlstarlet-1.6.1
"

S="${WORKDIR}/${PN}-${MY_PV}"

src_prepare() {
	default
	# <command to be executed on file> <file to be changed> [ message on failure ]
	# It is expected, that the last parameter of the command is the filename.
	# Other commands are not supported.
	# example args: sed -i -Ee 's/sample/sample2/' exampleFile "we will all die"
	checkChanged() {
		local dieMessage= args= lastArgIndex= srcFile= lastArg=
		args=( "${@@Q}" )
		lastArgIndex="${#}"; let lastArgIndex--
		lastArg="${args[${lastArgIndex}]}"
		# unquote argument with xargs
		if [[ -e "$(echo ${args[${lastArgIndex}]} | xargs)" ]]; then
			dieMessage="file ${srcFile} was not changed, while it should have been"
		else
			dieMessage="${lastArg}"
			let lastArgIndex--
			args=( "${args[@]/${dieMessage}}" )
		fi
		srcFile="$(echo ${args[${lastArgIndex}]} | xargs)"
		[[ ! -e "${srcFile}" ]] && die "Could not find file ${srcFile}"
		local tempFile="${T}/${srcFile##*/}"
		[[ -e "${tempFile}" ]] && die "${tempFile} already exists.  Refusing to overwrite"
		# remove file argument as we’re replacing it with the temporary file
		args=( "${args[@]/${args[${lastArgIndex}]}}" )
		cp "${srcFile}" "${tempFile}" || die "Copying file ${srcFile} to ${tempFile} failed"
		eval ${args[*]} "${tempFile}" || die "Could not execute command ${args[*]} on file ${tempFile}"
		# here the message argument is actually used ;)
		[[ -z $(diff "${srcFile}" "${tempFile}") ]] && \
			die "$(echo ${dieMessage} | xargs)"
		mv "${tempFile}" "${srcFile}" || die "moving ${tempFile} back to ${srcFile} failed"
	}

	# make sure bundled opus is not used
	rm -r libs/opus

	local translationDir="src/res/translation"
	local sedTranslationAddress='/^TRANSLATIONS.*\\$/,\~^[[:space:]]*'"${translationDir}"'/.*\.ts$~'
	local dieMessage=""
	remove_locale() {
		dieMessage="Removal of translation failed"
		rm "${translationDir}/translation_${1}.ts" || die "${dieMessage}"
		rm "${translationDir}/translation_${1}.qm" || die "${dieMessage}"
		local sedTranslationReplacement='s~'"${translationDir}"'/translation_'"${1}"'\.ts( \\)?$~\1~'
		local sedDeleteTranslationQm='\~^[[:space:]]+'"${translationDir}"'/translation_'"${1}"'\.qm *\\$~{d}'
		dieMessage="Sed replacements failed on ${MY_PN}.pro"
		local sedExp="${sedTranslationAddress}"'{'"${sedTranslationReplacement}"'}'
		checkChanged sed -i -Ee "${sedTranslationAddress}"'{'"${sedTranslationReplacement}"'}' ${MY_PN}.pro "${dieMessage}"
		checkChanged sed -i -Ee "${sedDeleteTranslationQm}" ${MY_PN}.pro "${dieMessage}"
		dieMessage="XML edit of resources.qrc failed"
		local xpath='/RCC/qresource/file[.="res/translation/translation_'"${1}"'.qm"]/parent::qresource'
		checkChanged xmlstarlet edit --inplace -d "${xpath}" src/resources.qrc "${dieMessage}"
	}

	l10n_find_plocales_changes "${S}/${translationDir}" 'translation_' '.ts'
	l10n_for_each_disabled_locale_do remove_locale
	if [[ $(l10n_get_locales) == "${PLOCALE_BACKUP}" ]]; then
		dieMessage="cleanup of translation variable failed"
		checkChanged sed -i -Ee '/^TRANSLATIONS = *\\$/,/^[[:space:]]*\\$/{d}' ${MY_PN}.pro "${dieMessage}"
	fi
}

# The following src_configure function is implemented as default by portage, so
# you only need to call it if you need a different behaviour.
src_configure() {
	local qmakeargs=( 'CONFIG+=opus_shared_lib' )
	qmakeargs+=( 'CONFIG+=noupcase' )
	if ! use client && use server; then
		qmakeargs+=( 'CONFIG+=headless' )
		! use jack && qmakeargs+=( 'CONFIG+=nosound' )
	fi
	eqmake5 "${qmakeargs[@]}"
	# replace /usr/local install paths
	sed -i -e 's~/usr/local~/usr~g' Makefile
}

src_compile() {
	emake clean
	emake
}

# The following src_compile function is implemented as default by portage, so
# you only need to call it, if you need different behaviour.

src_install() {
	emake -E "INSTALL_ROOT = ${D}" install
	readme.gentoo_create_doc
}

DISABLE_AUTOFORMATTING="true"
DOC_CONTENTS="
Upstream recommends media-sound/qjackctl for the configuration of your
Jack server, but Gentoo Wiki recommends media-sound/cadence, which is
more powerful.

sys-kernel/rt-sources with PREEMPT_RT will reduce jack xruns
significantly.  The difference expressed in period size with 2 buffers
is 256 vs 64, however you just need 128.  Your user must have rtprio
permissions e.g.

# /etc/security/limits.conf
*     soft rtprio 0
*     hard rtprio 0
larry soft rtprio 30
larry hard rtprio 50

Doc tl;dr:

Jack duplex mode will increase latency and is not recommended.  Upstream
recommends
1. an ethernet connection,
2. using a server with ping times below 15ms,
3. bandwidth: 10Mbps down; 1Mbps up,
4. dedicated microphone and headphones
5. an USB audio interface
6. network hardware without bufferbloat e.g. a router with OpenWrt and
___net.core.default_qdisc=fq_codel (https://www.bufferbloat.net)

If you have latencies above 44ms try the above recommendations in order
until it works.  If latency is okay and you have trouble keeping in
time, try to make it easier to focus on the audio stream, that is coming
back from the server e.g. increase headphones volume.
"

pkg_postinst() {
	readme.gentoo_print_elog
}
