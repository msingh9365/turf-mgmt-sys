# Migration to allow multiple slots per booking_id

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('bookings', '0002_rename_unique_id_to_booking_id'),
    ]

    operations = [
        # Step 1: Add a temporary auto-increment id column
        migrations.RunSQL(
            sql='ALTER TABLE "Booking" ADD COLUMN "id" BIGSERIAL;',
            reverse_sql='ALTER TABLE "Booking" DROP COLUMN "id";',
        ),
        
        # Step 2: Drop the primary key constraint from Booking_ID
        migrations.RunSQL(
            sql='ALTER TABLE "Booking" DROP CONSTRAINT "Booking_pkey";',
            reverse_sql='ALTER TABLE "Booking" ADD CONSTRAINT "Booking_pkey" PRIMARY KEY ("Booking_ID");',
        ),
        
        # Step 3: Set id as the new primary key
        migrations.RunSQL(
            sql='ALTER TABLE "Booking" ADD CONSTRAINT "Booking_pkey" PRIMARY KEY ("id");',
            reverse_sql='ALTER TABLE "Booking" DROP CONSTRAINT "Booking_pkey";',
        ),
        
        # Step 4: Create an index on Booking_ID for faster lookups
        migrations.RunSQL(
            sql='CREATE INDEX "Booking_Booking_ID_idx" ON "Booking" ("Booking_ID");',
            reverse_sql='DROP INDEX "Booking_Booking_ID_idx";',
        ),
    ]
