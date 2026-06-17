<?php
/**
 * DDEV local overrides (loaded after vip-config/vip-config.php from wp-config.php).
 *
 * Safe to add to existing VIP application repos — does not replace vip-config.php.
 *
 * @see https://docs.wpvip.com/wordpress-skeleton/vip-config-directory/
 */

// Jetpack WAF writes to wp-content/jetpack-waf; VIP filesystem only allows /tmp/ and uploads.
if ( ! defined( 'DISABLE_JETPACK_WAF' )
	&& defined( 'VIP_GO_APP_ENVIRONMENT' )
	&& 'local' === VIP_GO_APP_ENVIRONMENT ) {
	define( 'DISABLE_JETPACK_WAF', true );
}

if ( defined( 'VIP_GO_APP_ENVIRONMENT' ) && 'local' === VIP_GO_APP_ENVIRONMENT ) {
	if ( ! defined( 'WP_DEBUG_DISPLAY' ) ) {
		define( 'WP_DEBUG_DISPLAY', false );
	}
	if ( ! defined( 'WP_DEBUG_LOG' ) ) {
		define( 'WP_DEBUG_LOG', true );
	}
}

// Enterprise Search (local elasticsearch add-on).
if ( ! defined( 'VIP_ENABLE_VIP_SEARCH' ) ) {
	define( 'VIP_ENABLE_VIP_SEARCH', true );
}
if ( ! defined( 'VIP_ENABLE_VIP_SEARCH_QUERY_INTEGRATION' ) ) {
	define( 'VIP_ENABLE_VIP_SEARCH_QUERY_INTEGRATION', true );
}

if ( ! defined( 'VIP_ELASTICSEARCH_ENDPOINTS' )
	&& defined( 'VIP_GO_APP_ENVIRONMENT' )
	&& 'local' === VIP_GO_APP_ENVIRONMENT ) {
	$ddev_primary = getenv( 'DDEV_PRIMARY_URL' );
	$es_endpoint  = $ddev_primary ? rtrim( $ddev_primary, '/' ) . ':9201' : 'http://elasticsearch:9200';
	define( 'VIP_ELASTICSEARCH_ENDPOINTS', array( $es_endpoint ) );
	define( 'VIP_ELASTICSEARCH_USERNAME', 'ddev' );
	define( 'VIP_ELASTICSEARCH_PASSWORD', 'ddev' );
	define( 'VIP_ELASTICSEARCH_VERSION', '8' );
	if ( ! defined( 'FILES_CLIENT_SITE_ID' ) ) {
		define( 'FILES_CLIENT_SITE_ID', 200508 );
	}
}
