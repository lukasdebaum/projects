<?php

$mailuser = $argv[1];
$addressbook_file = $argv[2];
$with_groups = true;

define('INSTALL_PATH', '/data/web/webmail-dev/home/web/' );
require_once INSTALL_PATH.'program/include/clisetup.php';
#$rcmail->config->load_from_file($args['config']);


function import_group_id($group_name, $contacts, $create, &$import_groups)
{
	$group_id = 0;
	foreach ($import_groups as $group) {
		if (strtolower($group['name']) === strtolower($group_name)) {
			$group_id = $group['ID'];
			break;
		}
	}

	// create a new group
	if (!$group_id && $create) {
		$new_group = $contacts->create_group($group_name);

		if (empty($new_group['ID'])) {
			$new_group['ID'] = $new_group['id'];
		}

		$import_groups[] = $new_group;
		$group_id        = $new_group['ID'];
	}

	return $group_id;
}


if (!file_exists($addressbook_file)) {
	print("ERROR: " . $mailuser . " - file not found " . $addressbook_file . "\n");
    exit();
}


$db = $rcmail->get_dbh();
if (!$db) {
	print("ERROR: " . $mailuser . " - mysql connection failed" . "\n");
    exit();
}

$sql_result = $db->query(
	"SELECT * FROM " . $db->table_name('users', true)
	. " WHERE `username` = ?", $mailuser
);
$sql_arr = $db->fetch_assoc($sql_result);
if (!$sql_arr) {
	print("ERROR: "  . $mailuser .  " - no user_id found" . "\n");
    exit();
}

###
$userid = $sql_arr['user_id'];
if (!is_numeric($userid)) {
	print("ERROR: "  . $mailuser . " - no valid user_id found" . "\n");
    exit();
}
$rcmail->user->ID = $userid;

$CONTACTS = $rcmail->get_address_book("sql", true);

$vcard_o = new rcube_vcard();
$vcard_o->extend_fieldmap($CONTACTS->vcard_map);
$vcards = $vcard_o->import(file_get_contents($addressbook_file));

$import_groups = $CONTACTS->list_groups();

foreach ($vcards as $vcard) {
    $a_record = $vcard->get_assoc();

	// Generate contact's display name (must be before validation
	if (empty($a_record['name'])) {
		$a_record['name'] = rcube_addressbook::compose_display_name($a_record, true);
		if ($a_record['name'] == $a_record['email'][0]) {
			$a_record['name'] = '';
		}
	}

    // skip invalid (incomplete) entries
    if (!$CONTACTS->validate($a_record, true)) {
		print("ERROR: " . $mailuser .  " - invalid contact: ");
		print(json_encode($a_record));
		print("\n");
    	continue;
	}
	#print(json_encode($a_record) . "\n");
    
    if (mb_strlen($a_record['name'], 'UTF-8') >= 128) {
		$a_record['name'] = mb_strcut($a_record['name'], 0, 128, "UTF-8");
    }
    if (mb_strlen($a_record['firstname'], 'UTF-8') >= 128) {
		$a_record['firstname'] = mb_strcut($a_record['firstname'], 0, 128, "UTF-8");
    }
    if (mb_strlen($a_record['surname'], 'UTF-8') >= 128) {
		$a_record['surname'] = mb_strcut($a_record['surname'], 0, 128, "UTF-8");
    }

    $email = $vcard->email[0];
    $email = rcube_utils::idn_to_utf8($email);

	$a_record['vcard'] = $vcard->export();

	$plugin   = $rcmail->plugins->exec_hook('contact_create', ['record' => $a_record, 'source' => null]);
	$a_record = $plugin['record'];

	$success = $CONTACTS->insert($a_record);

	if ($with_groups && !empty($a_record['groups'])) {
		foreach (explode(',', $a_record['groups'][0]) as $group_name) {
			if ($group_id = import_group_id($group_name, $CONTACTS, $with_groups == 1, $import_groups)) {
				$CONTACTS->add_to_group($group_id, $success);
			}
		}
	}

    if (!$success) {
	    print("ERROR: " . $mailuser . " - failed to add vcard, message: " . $success . "\n");
    }
}


?>
