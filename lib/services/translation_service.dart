import 'api_service.dart';

class TranslationService {
  static final TranslationService instance = TranslationService._init();
  TranslationService._init();

  String get currentLanguage {
    final userLang = ApiService.instance.currentUser?.language ?? 'English';
    return userLang.toLowerCase() == 'tagalog' ? 'tl' : 'en';
  }

  static const Map<String, Map<String, String>> _keys = {
    'loading_text': {
      'en': 'Loading up everything for you, please take a moment...',
      'tl': 'Nilo-load ang lahat para sa iyo, sandali lamang po...'
    },
    'hello': {
      'en': 'Hello',
      'tl': 'Kumusta'
    },
    'new_run': {
      'en': 'New Grocery Run',
      'tl': 'Bagong Listahan ng Bilihin'
    },
    'run_title': {
      'en': 'Run Title (e.g. Weekly Groceries)',
      'tl': 'Pangalan ng Listahan'
    },
    'title_required': {
      'en': 'Title is required',
      'tl': 'Kailangan ng pangalan'
    },
    'budget_limit': {
      'en': 'Limit / Budget (PHP)',
      'tl': 'Limitasyon sa Badyet (PHP)'
    },
    'budget_required': {
      'en': 'Budget is required',
      'tl': 'Kailangan ng badyet'
    },
    'valid_number': {
      'en': 'Enter a valid number',
      'tl': 'Maglagay ng tamang numero'
    },
    'dashboard_title': {
      'en': 'TIPI DASHBOARD',
      'tl': 'TIPI DASHBOARD'
    },
    'monthly_budget': {
      'en': 'Monthly Budget Limit',
      'tl': 'Limit sa Badyet'
    },
    'used': {
      'en': 'Used',
      'tl': 'Ginamit'
    },
    'recent_runs': {
      'en': 'Recent Shopping Runs',
      'tl': 'Mga Kamakailang Pagbili'
    },
    'budget': {
      'en': 'Budget',
      'tl': 'Badyet'
    },
    'spent': {
      'en': 'Spent',
      'tl': 'Gastos'
    },
    'saved': {
      'en': 'Saved',
      'tl': 'Naipon'
    },
    'active': {
      'en': 'Active',
      'tl': 'Aktibo'
    },
    'completed': {
      'en': 'Completed',
      'tl': 'Tapos Na'
    },
    'items_count': {
      'en': 'items',
      'tl': 'mga gamit'
    },
    'grocery_runs_title': {
      'en': 'Grocery Runs',
      'tl': 'Listahan ng Bilihin'
    },
    'create_run': {
      'en': 'Create Run',
      'tl': 'Gumawa ng Listahan'
    },
    'run_name_label': {
      'en': 'Run Name (e.g. Weekly Groceries)',
      'tl': 'Pangalan ng Listahan (hal. Lingguhang Bilihin)'
    },
    'budget_limit_label': {
      'en': 'Budget Limit (PHP)',
      'tl': 'Limitasyon ng Badyet (PHP)'
    },
    'cancel': {
      'en': 'CANCEL',
      'tl': 'IKANSELA'
    },
    'create': {
      'en': 'CREATE',
      'tl': 'GUMAWA'
    },
    'finish_run': {
      'en': 'FINISH RUN',
      'tl': 'TAPUSIN ANG PAGBILI'
    },
    'add_commodity': {
      'en': 'Add Commodity',
      'tl': 'Magdagdag ng Bilihin'
    },
    'profile_title': {
      'en': 'My Profile',
      'tl': 'Aking Profile'
    },
    'runs_completed': {
      'en': 'Runs Completed',
      'tl': 'Mga Natapos na Pagbili'
    },
    'total_saved': {
      'en': 'Total Savings',
      'tl': 'Kabuuang Naipon'
    },
    'settings_language': {
      'en': 'Language / Wika',
      'tl': 'Wika / Language'
    },
    'settings_theme': {
      'en': 'Dark Mode Theme',
      'tl': 'Tema ng Dark Mode'
    },
    'logout': {
      'en': 'LOG OUT',
      'tl': 'MAG-LOG OUT'
    },
    'no_runs_yet': {
      'en': 'No grocery runs found. Tap + to start!',
      'tl': 'Walang nakitang listahan. I-tap ang + para magsimula!'
    },
    'terms_conditions': {
      'en': 'I agree to the Terms & Conditions. I understand the price reference is sourced from WFP (Davao del Norte only).',
      'tl': 'Sumasang-ayon ako sa mga Tuntunin at Kundisyon. Nauunawaan ko na ang reference ng presyo ay mula sa WFP (Davao del Norte lamang).'
    },
    'password_label': {
      'en': 'Password',
      'tl': 'Password'
    },
    'email_label': {
      'en': 'Email Address',
      'tl': 'Email Address'
    },
    'name_label': {
      'en': 'Full Name',
      'tl': 'Buong Pangalan'
    },
    'budget_goal_label': {
      'en': 'Monthly Budget Goal (PHP)',
      'tl': 'Buwanang Layunin sa Badyet (PHP)'
    },
    'login_btn': {
      'en': 'LOG IN',
      'tl': 'MAG-LOG IN'
    },
    'register_btn': {
      'en': 'REGISTER',
      'tl': 'MAGPAREHISTRO'
    },
    'no_account': {
      'en': "Don't have an account? Register",
      'tl': "Walang account? Magparehistro"
    },
    'has_account': {
      'en': 'Already have an account? Login',
      'tl': 'May account na? Mag-login'
    },
    'add_custom_item': {
      'en': 'Add custom item...',
      'tl': 'Magdagdag ng sariling item...'
    },
    'custom_item_subtitle': {
      'en': 'Create a commodity not found in the WFP database',
      'tl': 'Gumawa ng item na wala sa WFP database'
    },
    'shopper_shared': {
      'en': 'Shopper Shared',
      'tl': 'Bahagi ng Mamimili'
    },
    'wfp_reference': {
      'en': 'WFP Reference',
      'tl': 'Sanggunian ng WFP'
    },
    'custom_price_label': {
      'en': 'Custom Price',
      'tl': 'Sariling Presyo'
    },
    'qty_needed': {
      'en': 'Quantity Needed',
      'tl': 'Dami na Kailangan'
    },
    'add_to_list': {
      'en': 'ADD TO LIST',
      'tl': 'IDAGDAG SA LISTAHAN'
    },
    'finish_success': {
      'en': 'Grocery Run Finished Successfully!',
      'tl': 'Matagumpay na Natapos ang Pagbili!'
    },
    'savings_msg': {
      'en': 'You saved',
      'tl': 'Nakaipon ka ng'
    },
    'generate_receipt_prompt': {
      'en': 'Would you like to generate a shareable TIPI E-Receipt?',
      'tl': 'Gusto mo bang gumawa ng shareable na TIPI E-Receipt?'
    },
    'yes': {
      'en': 'YES',
      'tl': 'OO'
    },
    'no': {
      'en': 'NO',
      'tl': 'HINDI'
    },
    'receipt_copied': {
      'en': 'E-Receipt details copied to clipboard!',
      'tl': 'Kopyado na sa clipboard ang detalye ng E-Receipt!'
    },
    'save_changes': {
      'en': 'SAVE CHANGES',
      'tl': 'I-SAVE ANG MGA PAGBABAGO'
    },
    'profile_updated': {
      'en': 'Profile updated successfully!',
      'tl': 'Matagumpay na na-update ang profile!'
    },
    'profile_failed': {
      'en': 'Failed to update profile. Please try again.',
      'tl': 'Bigo sa pag-update ng profile. Subukan muli.'
    }
  };

  String t(String key) {
    if (!_keys.containsKey(key)) return key;
    return _keys[key]![currentLanguage] ?? _keys[key]!['en'] ?? key;
  }
}
