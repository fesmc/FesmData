# Global SMB database

The SUMup collaborative database: Surface mass balance, subsurface temperature and density measurements from the Greenland and Antarctic ice sheets (2025 release)

Source: https://arcticdata.io/catalog/view/doi:10.18739/A2M61BR5M

Citation: Baptiste Vandecrux, Charles Amory, Andreas P. Ahlstrøm, Pete D. Akers, Mary Albert, Richard B. Alley, Marcela Alves de Castro, Laurent Arnaud, Hannah Bailey, Ian Baker, Roger Bales, Carl Benson, Jason E. Box, Ludovic Brucker, Christo Buizert, David Chandler, Charalampos Charalampidis, Clément Cherblanc, Nicole Clerx, William Colgan, Federico Covi, Marissa Dattler, Gilles Denis, Chris Derksen, Jack E. Dibb, Minghu Ding, Daniel Dixon, Olaf Eisen, Alexey Ekaykin, Dominik Fahrner, Robert Fausto, Vincent Favier, Francisco Fernandoy, Richard Forster, Johannes Freitag, Massimo Frezzotti, Sebastian Gerland, Joel Harper, Robert L. Hawley, Achim Heilig, Jasper Heuer, Regine Hock, Shugui Hou, Penelope How, Ian Howat, Neil Humphrey, Alun Hubbard, Bryn Hubbard, Yoshinori Iizuka, Elisabeth Isaksson, Surendra Jat, Takao Kameda, Nanna B. Karlsson, Kaoru Kawakami, Christoph Kittel, Helle Astrid Kjær, Karl Kreutz, Peter Kuipers Munneke, Matthew Lazzara, Emmanuel Lemeur, Jan T. M. Lenaerts, Gabriel Lewis, Filipe Gaudie Ley Lindau, Josephine Lindsey-Clark, Michael MacFerrin, Horst Machguth, Olivier Magand, Kenneth D. Mankoff, Luciano Marquetto, Patricia Martinerie, Paul A. Mayewski, Joseph R. McConnell, Brooke Medley, Clément Miège, Katie E. Miles, Olivia Miller, Heinrich Miller, Lynn Montgomery, Hameed Moqadam, Elizabeth Morris, Ellen Mosley-Thompson, Robert Mulvaney, Masashi Niwano, Hans Oerter, Erich Osterberg, Inès Otosaka, Ikumi Oyabu, Ghislain Picard, Chris Polashenski, Carleen Reijmer, Asa Rennermalm, Anja Rutishauser, Kirk Scanlan, Jefferson C Simoes, Sebastian B. Simonsen, Paul C.J.P. Smeets, Andrew Smith, Anne Solgaard, Matthew Spencer, Hans Christian Steen-Larsen, C. Max Stevens, Shin Sugiyama, Jonas Svensson, Marco Tedesco, Elizabeth Thomas, Megan Thompson-Munson, Shun Tsutaki, Dirk van As, Michiel R. Van den Broeke, Maurice van Tiggelen, Yetang Wang, Nander Wever, Frank Wilhelms, Mai Winstrup, V. Holly L Winton, Cunde Xiao, & Jing Xiao. (2025). The SUMup collaborative database: Surface mass balance, subsurface temperature and density measurements from the Greenland and Antarctic ice sheets (2025 release). Arctic Data Center. doi:10.18739/A2M61BR5M, version: urn:uuid:96e5fbe1-60be-45fc-aaab-01b2c31e5901.

## Steps to get data

1. Download the complete dataset.

    ```
    wget https://arcticdata.io/metacat/d1/mn/v2/packages/application%2Fbagit-1.0/resource_map_urn%3Auuid%3A512f939c-60b3-4607-b922-c6cab3d326f3
    unzip resource_map_urn:uuid:512f939c-60b3-4607-b922-c6cab3d326f3
    rm resource_map_urn:uuid:512f939c-60b3-4607-b922-c6cab3d326f3
    rm *.txt
    mv data/* ./
    rm -r data
    
    ```
