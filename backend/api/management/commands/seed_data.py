"""
Management command to seed initial data
"""
from django.core.management.base import BaseCommand
from django.contrib.auth import get_user_model
from api.models import SportsType, Ground, TimeSlot
from datetime import time

User = get_user_model()


class Command(BaseCommand):
    help = 'Seed database with initial data'

    def handle(self, *args, **kwargs):
        self.stdout.write('Seeding database...')

        # Create sports types
        sports_types = [
            {'name': 'Football', 'description': 'Football ground for 11-a-side matches'},
            {'name': 'Cricket', 'description': 'Cricket ground with pitch'},
            {'name': 'Basketball', 'description': 'Basketball court'},
            {'name': 'Volleyball', 'description': 'Volleyball court'},
            {'name': 'Badminton', 'description': 'Badminton court'},
            {'name': 'Tennis', 'description': 'Tennis court'},
        ]

        self.stdout.write('Creating sports types...')
        created_sports = []
        for sport_data in sports_types:
            sport, created = SportsType.objects.get_or_create(
                name=sport_data['name'],
                defaults={'description': sport_data['description']}
            )
            created_sports.append(sport)
            if created:
                self.stdout.write(self.style.SUCCESS(f'Created: {sport.name}'))
            else:
                self.stdout.write(f'Already exists: {sport.name}')

        # Create grounds
        football_sport = SportsType.objects.get(name='Football')
        cricket_sport = SportsType.objects.get(name='Cricket')
        basketball_sport = SportsType.objects.get(name='Basketball')

        grounds_data = [
            {
                'name': 'Main Football Ground',
                'location': 'Sports Complex A',
                'sports_type': football_sport,
                'capacity': 22,
                'description': 'Main football ground with floodlights',
                'amenities': 'Floodlights, Changing Rooms, Water Facility',
            },
            {
                'name': 'Cricket Ground',
                'location': 'Sports Complex B',
                'sports_type': cricket_sport,
                'capacity': 30,
                'description': 'Cricket ground with turf pitch',
                'amenities': 'Practice Nets, Pavilion, Scoreboard',
            },
            {
                'name': 'Basketball Court 1',
                'location': 'Indoor Stadium',
                'sports_type': basketball_sport,
                'capacity': 20,
                'description': 'Indoor basketball court',
                'amenities': 'Air Conditioning, Seating, Sound System',
            },
        ]

        self.stdout.write('Creating grounds...')
        created_grounds = []
        for ground_data in grounds_data:
            ground, created = Ground.objects.get_or_create(
                name=ground_data['name'],
                defaults=ground_data
            )
            created_grounds.append(ground)
            if created:
                self.stdout.write(self.style.SUCCESS(f'Created: {ground.name}'))
            else:
                self.stdout.write(f'Already exists: {ground.name}')

        # Create time slots
        time_slots = [
            time(6, 0),   # 6:00 AM
            time(7, 0),   # 7:00 AM
            time(8, 0),   # 8:00 AM
            time(16, 0),  # 4:00 PM
            time(17, 0),  # 5:00 PM
            time(18, 0),  # 6:00 PM
            time(19, 0),  # 7:00 PM
        ]

        self.stdout.write('Creating time slots...')
        for ground in created_grounds:
            for i, start in enumerate(time_slots):
                if i < len(time_slots) - 1:
                    end = time_slots[i + 1]
                else:
                    end = time(20, 0)  # 8:00 PM for last slot

                slot, created = TimeSlot.objects.get_or_create(
                    ground=ground,
                    start_time=start,
                    end_time=end,
                )
                if created:
                    self.stdout.write(
                        self.style.SUCCESS(
                            f'Created slot: {ground.name} {start}-{end}'
                        )
                    )

        # Create sample users
        self.stdout.write('Creating sample users...')
        
        # Create admin user
        if not User.objects.filter(username='admin').exists():
            admin = User.objects.create_superuser(
                username='admin',
                email='admin@example.com',
                password='admin123',
                user_type='admin',
                first_name='Admin',
                last_name='User',
            )
            self.stdout.write(self.style.SUCCESS('Created admin user'))
        else:
            self.stdout.write('Admin user already exists')

        # Create sample student
        if not User.objects.filter(username='student1').exists():
            student = User.objects.create_user(
                username='student1',
                email='student1@example.com',
                password='student123',
                user_type='student',
                first_name='John',
                last_name='Doe',
                department='Computer Science',
                roll_number='CS2021001',
            )
            self.stdout.write(self.style.SUCCESS('Created student1 user'))
        else:
            self.stdout.write('Student1 user already exists')

        # Create sample faculty
        if not User.objects.filter(username='faculty1').exists():
            faculty = User.objects.create_user(
                username='faculty1',
                email='faculty1@example.com',
                password='faculty123',
                user_type='faculty',
                first_name='Jane',
                last_name='Smith',
                department='Physical Education',
            )
            self.stdout.write(self.style.SUCCESS('Created faculty1 user'))
        else:
            self.stdout.write('Faculty1 user already exists')

        self.stdout.write(self.style.SUCCESS('\n=== Database seeding completed! ==='))
        self.stdout.write('\nSample credentials:')
        self.stdout.write('Admin: username=admin, password=admin123')
        self.stdout.write('Student: username=student1, password=student123')
        self.stdout.write('Faculty: username=faculty1, password=faculty123')
