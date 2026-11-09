using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Kafamdakiler.Migrations
{
    /// <inheritdoc />
    public partial class TekBildirimHatti : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "Anahtar",
                table: "Bildirimler",
                type: "character varying(400)",
                maxLength: 400,
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_Bildirimler_KullaniciId_Anahtar",
                table: "Bildirimler",
                columns: new[] { "KullaniciId", "Anahtar" },
                unique: true,
                filter: "\"Anahtar\" IS NOT NULL");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Bildirimler_KullaniciId_Anahtar",
                table: "Bildirimler");

            migrationBuilder.DropColumn(
                name: "Anahtar",
                table: "Bildirimler");
        }
    }
}
