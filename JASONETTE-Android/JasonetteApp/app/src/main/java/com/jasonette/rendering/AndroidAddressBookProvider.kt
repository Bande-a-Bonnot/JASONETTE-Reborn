package com.jasonette.rendering

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.provider.ContactsContract
import androidx.core.content.ContextCompat
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/** Minimal production provider for legacy `$util.addressbook`. */
class AndroidAddressBookProvider(private val context: Context) {
    suspend fun contacts(): List<Map<String, String>> = withContext(Dispatchers.IO) {
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.READ_CONTACTS) != PackageManager.PERMISSION_GRANTED) {
            throw ActionDispatcher.ActionException("Contacts permission denied")
        }
        val resolver = context.contentResolver
        val contacts = mutableListOf<Map<String, String>>()
        resolver.query(
            ContactsContract.Contacts.CONTENT_URI,
            arrayOf(
                ContactsContract.Contacts._ID,
                ContactsContract.Contacts.DISPLAY_NAME
            ),
            null,
            null,
            null
        )?.use { cursor ->
            val idIndex = cursor.getColumnIndexOrThrow(ContactsContract.Contacts._ID)
            val nameIndex = cursor.getColumnIndexOrThrow(ContactsContract.Contacts.DISPLAY_NAME)
            while (cursor.moveToNext()) {
                val contactId = cursor.getString(idIndex) ?: continue
                val name = cursor.getString(nameIndex) ?: ""
                contacts.add(
                    mapOf(
                        "name" to name,
                        "phone" to lastPhone(contactId),
                        "email" to lastEmail(contactId)
                    )
                )
            }
        } ?: throw ActionDispatcher.ActionException("Address book unavailable")
        contacts
    }

    private fun lastPhone(contactId: String): String =
        context.contentResolver.query(
            ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
            arrayOf(ContactsContract.CommonDataKinds.Phone.NUMBER),
            "${ContactsContract.CommonDataKinds.Phone.CONTACT_ID} = ?",
            arrayOf(contactId),
            null
        )?.use { cursor ->
            val numberIndex = cursor.getColumnIndexOrThrow(ContactsContract.CommonDataKinds.Phone.NUMBER)
            var value = ""
            while (cursor.moveToNext()) {
                value = cursor.getString(numberIndex) ?: ""
            }
            value
        } ?: ""

    private fun lastEmail(contactId: String): String =
        context.contentResolver.query(
            ContactsContract.CommonDataKinds.Email.CONTENT_URI,
            arrayOf(ContactsContract.CommonDataKinds.Email.DATA),
            "${ContactsContract.CommonDataKinds.Email.CONTACT_ID} = ?",
            arrayOf(contactId),
            null
        )?.use { cursor ->
            val emailIndex = cursor.getColumnIndexOrThrow(ContactsContract.CommonDataKinds.Email.DATA)
            var value = ""
            while (cursor.moveToNext()) {
                value = cursor.getString(emailIndex) ?: ""
            }
            value
        } ?: ""
}
