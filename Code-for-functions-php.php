<?
// REST-API-Abfrage als Sicherung aus der functions.php des themes
// FEhlt: add custom field gallery to attachment!!!! : in Bitnami bereits vorhanden!

function register_gallery() {
	register_rest_field(
		'attachment',
		'gallery',
		array(
			'get_callback' => 'cb_get_gallery',
			'update_callback' => 'cb_upd_gallery',
			'schema' => array(
				'description' => 'gallery-field for Lightroom',
				'type' => 'string',
				)
			)	
		);
}

function cb_get_gallery ( $data ) {
	return (string) get_post_meta( $data['id'], 'gallery', true);
}

function cb_upd_gallery ( $value, $post) {
	update_post_meta( $post->ID, 'gallery', $value);
	return true;
};

add_action('rest_api_init', 'register_gallery');