# Generated migration to rename Unique_ID to Booking_ID and remove old Booking_ID column

from django.db import migrations


class Migration(migrations.Migration):

    dependencies = [
        ('bookings', '0001_initial'),
    ]

    operations = [
        # Step 1: Drop the existing Booking_ID column (if it exists)
        migrations.RunSQL(
            sql='ALTER TABLE "Booking" DROP COLUMN IF EXISTS "Booking_ID";',
            reverse_sql='-- Cannot reverse dropping Booking_ID column',
        ),
        
        # Step 2: Drop the primary key constraint on Unique_ID
        migrations.RunSQL(
            sql='ALTER TABLE "Booking" DROP CONSTRAINT "Booking_pkey";',
            reverse_sql='ALTER TABLE "Booking" ADD CONSTRAINT "Booking_pkey" PRIMARY KEY ("Unique_ID");',
        ),
        
        # Step 3: Rename Unique_ID column to Booking_ID
        migrations.RunSQL(
            sql='ALTER TABLE "Booking" RENAME COLUMN "Unique_ID" TO "Booking_ID";',
            reverse_sql='ALTER TABLE "Booking" RENAME COLUMN "Booking_ID" TO "Unique_ID";',
        ),
        
        # Step 4: Add primary key constraint on the renamed Booking_ID column
        migrations.RunSQL(
            sql='ALTER TABLE "Booking" ADD CONSTRAINT "Booking_pkey" PRIMARY KEY ("Booking_ID");',
            reverse_sql='ALTER TABLE "Booking" DROP CONSTRAINT "Booking_pkey";',
        ),
    ]
