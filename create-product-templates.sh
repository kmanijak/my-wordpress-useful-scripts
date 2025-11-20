<?php
/**
 * WP-CLI script to create single product templates from real products
 * 
 * Usage: wp eval-file create-product-templates.php [num_templates]
 * Example: wp eval-file create-product-templates.php 200
 */

// Get number of templates to create from args or default to 200
$num_templates = isset( $args[0] ) ? intval( $args[0] ) : 200;

WP_CLI::line( WP_CLI::colorize( "%G=== Creating {$num_templates} Single Product Templates ===%n" ) );
WP_CLI::line( '' );

// Fetch products from the store
$products = get_posts( array(
	'post_type'      => 'product',
	'posts_per_page' => $num_templates,
	'post_status'    => 'publish',
	'fields'         => 'ids',
) );

if ( empty( $products ) ) {
	WP_CLI::error( 'No products found in the store. Please add products first.' );
}

WP_CLI::line( WP_CLI::colorize( "%YFound " . count( $products ) . " products%n" ) );
WP_CLI::line( '' );

$created = 0;
$failed = 0;
$skipped = 0;

// Progress bar
$progress = \WP_CLI\Utils\make_progress_bar( 'Creating templates', count( $products ) );

foreach ( $products as $product_id ) {
	$product = wc_get_product( $product_id );
	
	if ( ! $product ) {
		$failed++;
		$progress->tick();
		continue;
	}
	
	$product_slug = $product->get_slug();
	$product_title = $product->get_name();
	$template_slug = 'single-product-' . $product_slug;
	
	// Check if template already exists
	$existing = get_posts( array(
		'post_type'   => 'wp_template',
		'post_status' => 'publish',
		'name'        => $template_slug,
		'numberposts' => 1,
	) );
	
	if ( ! empty( $existing ) ) {
		$skipped++;
		WP_CLI::debug( "Template already exists: {$template_slug}" );
		$progress->tick();
		continue;
	}
	
	// Create the template
	$template_data = array(
		'post_type'    => 'wp_template',
		'post_status'  => 'publish',
		'post_title'   => $template_slug,
		'post_name'    => $template_slug,
		'post_content' => '', // Empty content - will inherit from theme
	);
	
	$template_id = wp_insert_post( $template_data, true );
	
	if ( is_wp_error( $template_id ) ) {
		$failed++;
		WP_CLI::debug( "Failed to create: {$template_slug} - " . $template_id->get_error_message() );
		$progress->tick();
		continue;
	}
	
	// Set template metadata
	update_post_meta( $template_id, 'theme', get_stylesheet() );
	update_post_meta( $template_id, 'is_wp_suggestion', true );
	
	// Set taxonomy terms
	wp_set_object_terms( $template_id, 'wp_template', 'wp_template_type' );
	wp_set_object_terms( $template_id, get_stylesheet(), 'wp_theme' );
	
	$created++;
	WP_CLI::debug( WP_CLI::colorize( "%GCreated: {$template_slug}%n (Product: {$product_title})" ) );
	
	$progress->tick();
	
	// Stop if we've created enough templates
	if ( $created >= $num_templates ) {
		break;
	}
}

$progress->finish();

WP_CLI::line( '' );
WP_CLI::line( WP_CLI::colorize( "%G=== Summary ===%n" ) );
WP_CLI::success( "Created: {$created} templates" );
if ( $skipped > 0 ) {
	WP_CLI::line( WP_CLI::colorize( "%YSkipped (already exist): {$skipped}%n" ) );
}
if ( $failed > 0 ) {
	WP_CLI::warning( "Failed: {$failed}" );
}

