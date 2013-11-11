module Checkout
  class ChangePickupStoreDialog
    include PageObject
    include SiteSelector

    div  :container,                    :id => mcom_bcom('storeav-oy', 'bops_so_Panel_c')
    div  :error_message,                :class => mcom_bcom('error-msg', 'bl_errorContainer')
    h2   :title,                        :id => mcom_bcom('stp-ttl-bops', 'bops_so_headerText')
    link :close,                        mcom_bcom({:id => 'closeFindItInStoreOverlay_bops'}, {:class => 'container-close'})

    # Product info
    div  :product_title,                :id => mcom_bcom('storeOverlayProductName', 'bops_so_itemTitle')
    div  :product_detail_container,     :id => mcom_bcom('prod-ul', 'bops_so_itemDetailContainer')
    if macys?
      list_item(:product_color_size)    { product_detail_container_element.list_item_element(:index => 1) }
    else
      div :product_color,               :id => 'bops_so_itemColor'
      div :product_size,                :id => 'bops_so_itemSize'
      div :product_id,                  :id => 'bops_so_webID'
      div :product_price,               :id => 'bops_so_itemPrice'
    end

    # Search form
    text_field  :address_zip_code,      :id => mcom_bcom('bopsf1Zip', 'bops_so_zipCode')
    text_field  :address_city,          :id => mcom_bcom('bopsf1City', 'bops_so_city')
    select_list :address_state,         :id => mcom_bcom('bopsf1State', 'bops_so_state')
    select_list :search_distance,       :id => mcom_bcom('bopsf1Distance', 'bops_so_distance')

    # Search results
    div   :search_results_container,    :id => 'bops_so_searchResults'
    div   :search_button,               :id => mcom_bcom('bopsStoreSearchBtn', 'bops_so_searchButton')
    div   :save_button,                 :id => mcom_bcom('saveBottom', 'bops_so_saveButton')
    div   :cancel_button,               :id => mcom_bcom('cancelBottom', 'bops_so_cancelBottomButton')

    # Store container
    radio_buttons :select_store_button, mcom_bcom({:class => 'bopsStoreSelectButton'}, {:class => 'bl_inputCover'})
    links         :view_map_link,       :class => mcom_bcom('viewmap', 'bops_so_viewMap')
    divs          :map_containers,      mcom_bcom({:id => 'map.div1'}, {:class => 'bops_so_mapContainer'})
    divs          :store_header,        :class => mcom_bcom('scrollerheader', 'bops_so_storeAvailability')

    if macys?
      div     :loading_mask,                   :id => 'loading_mask'
      divs    :bops_store_container,           :class => 'store-boxa-bops'
      divs    :bops_store_container_selected,  :class => 'store-boxa-bops-selected'
      divs    :purchase_in_store_container,    :class => 'store-box-bops'
    else
      div     :store_container,                :id => 'bops_so_storesContainer'
      div     :store_availability_message,     :class => 'bops_so_storeAvailability'
      div     :store_count_div,                :class => 'bops_so_numberOfStores'
    end


    def initialize_page
      container_element.when_present
      wait_for_loading_mask
    end

    #
    # Searches for available stores within a given radius of the specified zip code or city/state.
    #
    # @param [Hash] data A hash containing possible key/values:
    #                      address_zip_code
    #                      address_city and address_state
    #                      search_distance
    #
    # @example Search for stores near 22033 and select a random one to have the item shipped to.
    #   on(Checkout::ChangePickupStoreDialog) do |dialog|
    #     dialog.search_for_stores('address_zip_code' => '22033')
    #     dialog.select_store(store_list.sample)
    #   end
    #
    def search_for_stores(data)
      Log.instance.debug "Searching for stores that match '#{data}'"
      populate_page_with(data)
      search_button_element.click
      wait_for_loading_mask
    end

    #
    # Returns the matching store search results.
    #
    # @example Print out all matching store data.
    #   on(Checkout::ChangePickupStoreDialog) do |dialog|
    #     dialog.search_for_stores('address_zip_code' => '22033')
    #     dialog.bops_store_list.each do |result|
    #       Log.instance.debug "Store name: #{result['store_name']}"
    #       Log.instance.debug "Distance from zip code: #{result['distance']}"
    #     end
    #
    def bops_store_list
      stores = []
      if macys?
       bops_elements = bops_store_container_elements.empty? ? bops_store_container_selected_elements : bops_store_container_elements
        bops_elements.each do |container|
          city, state = container.span_element(:class => 'line', :index => 4).text.split(',')
          state.strip!

          # The toggle button must be clicked before the items exist in the DOM.
          items = []
          if container.div_element(:class => 'itemsAvailability').visible?
            if container.div_element(:class => 'arrow-left').visible?
              container.div_element(:class => 'toggleItemAvailabilityButton').click
            end

            container.span_element(:class => 'itemAvailableInStore').unordered_list_elements.each do |list_element|
              items << {
                'title'       => list_element.list_item_element(:index => 0).text,
                'description' => list_element.list_item_element(:index => 1).text,
              }
            end
          end

          stores << {
              'store_name'       => container.span_element(:class => 'line', :index => 0).text,
              'address_line_1'   => container.span_element(:class => 'line', :index => 1).text,
              'address_line_2'   => container.span_element(:class => 'line', :index => 2).text,
              'address_city'     => city,
              'address_state'    => state,
              'address_zip_code' => container.span_element(:class => 'line', :index => 5).text,
              'distance'         => container.span_element(:class => 'miles-bops').text,
              'store_hours'      => container.div_element(:class =>'store-hours').text,
              'items'            => items,
          }
        end
      else
        raise 'Bops store not available' unless store_availability_message.include?('Buy online')

        store_count = store_count_div[/(\d+)/, 1].to_i
        container = store_container_element.div_elements(:class => 'bops_so_storeResultWrapper')
        store_count.times do |i|
          location_container = container[i].div_element(:class => 'bops_so_storeLocation')
          hours_container = container[i].div_element(:class => 'bops_so_storeHoursContainer')
          city_state_zip = location_container.div_element(:index => 2).text

          # The toggle button must be clicked before the items exist in the DOM.
          items = []
          if container[i].div_element(:class => 'bops_so_multiItemContainer').visible?
            items_container = container[i].div_element(:class => 'bops_so_multiItemContainer')

            if items_container.div_element(:class => 'bops_so_toggleItemAvailabilityBtnClosed').visible?
               items_container.div_element(:class => 'bops_so_toggleItemAvailabilityBtnClosed').click
            end

            title_elements       = items_container.div_elements(:class => 'bops_so_upcDetailsItemName')
            description_elements = items_container.div_elements(:class => 'bops_so_upcDetails')
            title_elements.size.times do |j|
              items << {
                  'title'       => title_elements[j].text,
                  'description' => description_elements[j].text,
              }
            end
          end
          stores << {
              'store_name'       => location_container.div_element(:index => 0).text,
              'address_line_1'   => location_container.div_element(:index => 1).text,
              'address_line_2'   => '',
              'address_city'     => city_state_zip[/([^,]+)/, 1],           # Everything up to the first ,
              'address_state'    => city_state_zip[/,(\w{2})/, 1],          # First two characters after the ,
              'address_zip_code' => city_state_zip[/(\d{5}(-\d{4})?)$/, 1], # Last 5 digits (plus optional 4 digits)
              'phone_number'     => location_container.div_element(:index => 3).text,
              'distance'         => location_container.span_element(:class => 'bops_so_storeMiles').text.sub(' View Map', '').sub(' Hide Map', ''),
              'store_hours'      => hours_container.text,
              'items'            => items,
          }
        end
      end
      stores
    end

    #
    # Returns the list of stores where items can be purchased in-store.
    #
    def purchase_in_store_list
      stores = []
      if macys?
        purchase_in_store_container_elements.each do |container|

          city, state = container.span_element(:class => 'line', :index => 4).text.split(',')
          state.strip!

          stores << {
              'store_name'       => container.span_element(:index => 0).text,
              'address_line_1'   => container.span_element(:class => 'line', :index => 0).text,
              'address_line_2'   => container.span_element(:class => 'line', :index => 1).text,
              'address_city'     => city,
              'address_state'    => state,
              'address_zip_code' => container.span_element(:class => 'line', :index => 4).text,
              'distance'         => container.span_element(:class => 'miles-bops').text,
              'store_hours'      => container.div_element(:class =>'store-hours').text,
          }
        end
      else
        instore_availability = false
        store_header = store_container_element.div_elements(:class => 'bops_so_storeAvailability').map(&:text)
          store_header.each do |header|
           if header.include?('not available for our buy online')
              instore_availability = true
              break
           end
        end
        raise 'No in-store available stores are found' unless instore_availability

        store_count = 0
        container = store_container_element.div_elements(:class => 'bops_so_storeResultWrapper')

        if store_availability_message.include?('Buy online')
          store_count = store_count_div[/(\d+)/, 1].to_i
          total_store_count = container.count - 1
        elsif store_availability_message.include?('not available for our buy online')
          total_store_count = container.count - 1
        end

        not_available_stores = false
          store_header.each do |header|
           if header.include?('Not available at')
              not_available_stores = true
              break
           end
        end

        if not_available_stores
          total_store_count -= 1
        end

        (store_count..total_store_count).each do |i|
          location_container = container[i].div_element(:class => 'bops_so_storeLocation')
          hours_container = container[i].div_element(:class => 'bops_so_storeHoursContainer')
          city_state_zip = location_container.div_element(:index => 2).text

          stores << {
              'store_name'       => location_container.div_element(:index => 0).text,
              'address_line_1'   => location_container.div_element(:index => 1).text,
              'address_line_2'   => '',
              'address_city'     => city_state_zip[/([^,]+)/, 1],           # Everything up to the first ,
              'address_state'    => city_state_zip[/,(\w{2})/, 1],          # First two characters after the ,
              'address_zip_code' => city_state_zip[/(\d{5}(-\d{4})?)$/, 1], # Last 5 digits (plus optional 4 digits)
              'phone_number'     => location_container.div_element(:index => 3).text,
              'distance'         => location_container.span_element(:class => 'bops_so_storeMiles').text.sub(' View Map', '').sub(' Hide Map', ''),
              'store_hours'      => hours_container.text
          }
        end
      end
      stores
    end

    #
    # Views the map for a specified store.
    #
    # @param [Hash] store A store hash from either the bops_store_list or purchase_in_store_list lists.
    # @param [String] store_type Either 'bops_store' or 'available_store'
    #
    # @example View the map for a random store in the search results
    #   on(ChangePickupStoreDialog) do |dialog|
    #     dialog.search_for_stores('address_zip_code' => '22033')
    #     stores = dialog.bops_store_list
    #     stores.should_not be_empty
    #     store = stores.sample
    #     dialog.view_map(store, 'bops_store')
    #     dialog.map_displayed?(store, 'bops_store').should be_true
    #   end
    def view_map(store, store_type)
      index = store_index(store, store_type)
      if macys?
        element = store_type == 'bops_store' ?
            select_store_button_elements[index] :
            purchase_in_store_container_elements[index].image_element
        element.click
      else
        view_map_link_elements[index].click
      end
    end

    #
    # Checks if a map is displayed (for MCOM, the store and store_type parameters are not used since
    # there is only one common map container used to display maps).  Refer to the view_map method
    # for an example of usage.
    #
    def map_displayed?(store, store_type)
      index = macys? ? 0 : store_index(store, store_type)
      map_containers_elements[index].visible?
    end

    #
    # Selects the specified store as the store to ship the item to and saves the selection.
    # The dialog is gone after this method is called.
    #
    def select_bops_store(store, store_type)
      index = store_index(store, store_type)
      select_store_button_elements[index].click
      save_button_element.click
    end

    #
    # Returns the product details as a hash.
    # @return [Hash] keys: 'title', 'color', 'size'
    #                BCOM also includes: 'id', 'price'
    #
    def product_details
      if macys?
        color_size = product_color_size.match(/Color: (.*), Size: (.*)/)
        raise "Unable to parse color and size from '#{product_color_size}'." if color_size.nil?
        product_info = {
            'title' => product_title,
            'color' => color_size[1],
            'size'  => color_size[2],
        }
      else
        product_info = {
            'title' => product_title,
            'color' => product_color,
            'size'  => product_size.sub('Size: ', ''),
            'id'    => product_id.sub('Web ID: ', ''),
            'price' => Currency.parse(product_price.sub('PRICE: ', '')).last,
        }
      end
      product_info
    end


    private

    #
    # Find the element index that the specified store matches.
    #
    def store_index(search_store, store_type)

      raise ArgumentError, 'search_store is nil' if search_store.nil?
      Log.instance.debug "Looking for store '#{search_store}'"
      bops_availablility = false

      if macys?
        bops_availablility = !bops_store_container_elements.empty? || !bops_store_container_selected_elements.empty?
      else
        store_header_text = store_container_element.div_element(:class => 'bops_so_storeAvailabilityContainer').div_element(:class => 'bops_so_storeAvailability').text
        bops_availablility = store_header_text.include?'Buy online'
      end

      case store_type
      when 'bops_store'
        bops_store_list.each_with_index do |store, index|
          Log.instance.debug "Comparing against store: '#{store}'"
          match = store.all? { |key, value| value == search_store[key] }
          if match
            Log.instance.debug 'Found a match.'
            return index
          end
        end
      when 'available_store'
        bops_store_count = 0
        if bops_availablility
          bops_store_count = bops_store_list.count
        end
        
        purchase_in_store_list.each_with_index do |store, index|
          Log.instance.debug "Comparing against store: '#{store}'"
          match = store.all? { |key, value| value == search_store[key] }
          if match
            Log.instance.debug 'Found a match.'
            if macys?
              return index
            else
              return index + bops_store_count
            end
          end
        end
      end
      raise StoreNotFoundError, "Unable to find a store that matches '#{search_store}'."
    end

    def wait_for_loading_mask
      wait_until(30, 'The loading mask is still visible.') do
        if macys?
          !loading_mask_element.visible?
        else
          !search_results_container_element.attribute('class').include?('loading')
        end
      end
    end
  end
end

class StoreNotFoundError < StandardError; end
