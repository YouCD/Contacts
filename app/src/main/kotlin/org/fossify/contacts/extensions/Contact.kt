package org.fossify.contacts.extensions

import org.fossify.commons.models.contacts.Contact

fun Contact.getDisplayName(): String = getNameToDisplay().replaceFirst(", ", "")
