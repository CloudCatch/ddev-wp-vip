<?php
/**
 * VIP-style config (loaded from wp-config.php after platform mu-plugins bootstrap).
 *
 * @see https://docs.wpvip.com/wordpress-skeleton/vip-config-directory/
 */

if ( ! defined( 'VIP_JETPACK_IS_PRIVATE' ) &&
	defined( 'VIP_GO_APP_ENVIRONMENT' ) &&
	'production' !== VIP_GO_APP_ENVIRONMENT ) {
	define( 'VIP_JETPACK_IS_PRIVATE', true );
}

// Jetpack WAF writes to wp-content/jetpack-waf; VIP filesystem only allows /tmp/ and uploads.
if ( ! defined( 'DISABLE_JETPACK_WAF' )
	&& defined( 'VIP_GO_APP_ENVIRONMENT' )
	&& 'local' === VIP_GO_APP_ENVIRONMENT ) {
	define( 'DISABLE_JETPACK_WAF', true );
}

if ( function_exists( 'newrelic_disable_autorum' ) ) {
	newrelic_disable_autorum();
}

if ( ( ! defined( 'VIP_GO_APP_ENVIRONMENT' ) || ( defined( 'VIP_GO_APP_ENVIRONMENT' ) && 'production' !== VIP_GO_APP_ENVIRONMENT ) )
	&& ! defined( 'WP_DEBUG' ) ) {
	define( 'WP_DEBUG', true );
}

if ( defined( 'VIP_GO_APP_ENVIRONMENT' ) && 'local' === VIP_GO_APP_ENVIRONMENT ) {
	if ( ! defined( 'WP_DEBUG_DISPLAY' ) ) {
		define( 'WP_DEBUG_DISPLAY', false );
	}
	if ( ! defined( 'WP_DEBUG_LOG' ) ) {
		define( 'WP_DEBUG_LOG', true );
	}
}

// Enterprise Search
if ( ! defined( 'VIP_ENABLE_VIP_SEARCH' ) ) {
	define( 'VIP_ENABLE_VIP_SEARCH', true );
}
if ( ! defined( 'VIP_ENABLE_VIP_SEARCH_QUERY_INTEGRATION' ) ) {
	define( 'VIP_ENABLE_VIP_SEARCH_QUERY_INTEGRATION', true );
}

// DDEV elasticsearch add-on (required for vip-search WP-CLI).
// HTTPS via ddev-router (:9201) avoids Query Monitor "non-HTTPS URL" warnings on an HTTPS site.
if ( ! defined( 'VIP_ELASTICSEARCH_ENDPOINTS' )
	&& defined( 'VIP_GO_APP_ENVIRONMENT' )
	&& 'local' === VIP_GO_APP_ENVIRONMENT ) {
	$ddev_primary = getenv( 'DDEV_PRIMARY_URL' );
	$es_endpoint  = $ddev_primary ? rtrim( $ddev_primary, '/' ) . ':9201' : 'http://elasticsearch:9200';
	define( 'VIP_ELASTICSEARCH_ENDPOINTS', array( $es_endpoint ) );
	define( 'VIP_ELASTICSEARCH_USERNAME', 'ddev' );
	define( 'VIP_ELASTICSEARCH_PASSWORD', 'ddev' );
	define( 'VIP_ELASTICSEARCH_VERSION', '8' );
	// Local site ID for index names (vip-{id}-{indexable}-{version}).
	if ( ! defined( 'FILES_CLIENT_SITE_ID' ) ) {
		define( 'FILES_CLIENT_SITE_ID', 200508 );
	}
}
