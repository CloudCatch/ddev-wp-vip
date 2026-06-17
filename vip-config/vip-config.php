<?php
/**
 * Minimal vip-config for greenfield DDEV + VIP skeleton projects.
 *
 * Existing VIP application repos already have vip-config/vip-config.php — keep yours.
 * DDEV local settings live in vip-config/vip-config-ddev.php (loaded from wp-config.php).
 *
 * @see https://docs.wpvip.com/wordpress-skeleton/vip-config-directory/
 */

if ( ! defined( 'VIP_JETPACK_IS_PRIVATE' ) &&
	defined( 'VIP_GO_APP_ENVIRONMENT' ) &&
	'production' !== VIP_GO_APP_ENVIRONMENT ) {
	define( 'VIP_JETPACK_IS_PRIVATE', true );
}

if ( function_exists( 'newrelic_disable_autorum' ) ) {
	newrelic_disable_autorum();
}

if ( ( ! defined( 'VIP_GO_APP_ENVIRONMENT' ) || ( defined( 'VIP_GO_APP_ENVIRONMENT' ) && 'production' !== VIP_GO_APP_ENVIRONMENT ) )
	&& ! defined( 'WP_DEBUG' ) ) {
	define( 'WP_DEBUG', true );
}
