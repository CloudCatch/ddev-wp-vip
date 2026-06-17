<?php
/**
 * DDEV database settings for local WordPress (VIP skeleton).
 *
 * Copied to wordpress/wp-config-ddev.php by bin/vip-setup.sh because
 * disable_settings_management prevents DDEV from generating this file.
 *
 * @package ddevapp
 */

if ( getenv( 'IS_DDEV_PROJECT' ) !== 'true' ) {
	return;
}

/** The name of the database for WordPress */
defined( 'DB_NAME' ) || define( 'DB_NAME', getenv( 'DB_NAME' ) ?: 'db' );

/** MySQL database username */
defined( 'DB_USER' ) || define( 'DB_USER', getenv( 'DB_USER' ) ?: 'db' );

/** MySQL database password */
defined( 'DB_PASSWORD' ) || define( 'DB_PASSWORD', getenv( 'DB_PASSWORD' ) ?: 'db' );

/** MySQL hostname */
defined( 'DB_HOST' ) || define( 'DB_HOST', getenv( 'DB_HOST' ) ?: 'db' );

/** WP_HOME URL */
defined( 'WP_HOME' ) || define( 'WP_HOME', getenv( 'DDEV_PRIMARY_URL' ) ?: 'http://localhost' );

/** WP_SITEURL location */
defined( 'WP_SITEURL' ) || define(
	'WP_SITEURL',
	WP_HOME . '/' . ltrim(
		str_replace(
			realpath( getenv( 'DDEV_APPROOT' ) . '/' . getenv( 'DDEV_DOCROOT' ) ),
			'',
			realpath( ABSPATH )
		),
		'/'
	)
);

/**
 * Set WordPress database table prefix if not already set.
 *
 * @global string $table_prefix
 */
if ( empty( $table_prefix ) ) {
	// phpcs:disable WordPress.WP.GlobalVariablesOverride.Prohibited
	$table_prefix = getenv( 'DB_PREFIX' ) ?: 'wp_';
	// phpcs:enable
}
