<?php
/**
 * DDEV local: Enterprise Search over HTTPS (router) and relaxed TLS verify.
 */

if ( ! defined( 'VIP_GO_APP_ENVIRONMENT' ) || 'local' !== VIP_GO_APP_ENVIRONMENT ) {
	return;
}

add_filter(
	'http_request_args',
	static function ( $args, $url ) {
		if ( ! is_string( $url ) ) {
			return $args;
		}
		if ( str_contains( $url, ':9201' ) || str_contains( $url, 'elasticsearch:' ) ) {
			$args['sslverify'] = false;
		}
		return $args;
	},
	10,
	2
);
